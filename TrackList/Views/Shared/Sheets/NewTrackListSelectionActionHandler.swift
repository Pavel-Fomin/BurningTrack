//
//  NewTrackListSelectionActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class NewTrackListSelectionActionHandler {

    /// Режим применения выбранных треков.
    private let mode: NewTrackListSelectionMode
    /// Возвращает актуальный выбор треков на момент подтверждения.
    private let selectedTracksProvider: () -> [LibraryTrack]
    /// Управляет созданием и пополнением треклистов.
    private let trackListsManager: TrackListsManager
    /// Показывает пользовательские сообщения.
    private let toastManager: ToastManager
    /// Управляет закрытием sheet.
    private let sheetManager: SheetManager

    init(
        mode: NewTrackListSelectionMode,
        selectedTracksProvider: @escaping () -> [LibraryTrack],
        trackListsManager: TrackListsManager? = nil,
        toastManager: ToastManager? = nil,
        sheetManager: SheetManager? = nil
    ) {
        self.mode = mode
        self.selectedTracksProvider = selectedTracksProvider
        self.trackListsManager = trackListsManager ?? .shared
        self.toastManager = toastManager ?? .shared
        self.sheetManager = sheetManager ?? .shared
    }

    /// Выполняет действие sheet-flow выбора треков.
    func handle(_ action: NewTrackListSelectionAction) {
        switch action {
        case .submit:
            Task {
                await submitSelectedTracks()
            }

        case .cancel:
            sheetManager.closeActive()
        }
    }

    /// Создаёт треклист с выбранными треками или добавляет их в существующий.
    private func submitSelectedTracks() async {
        let selectedTracks = selectedTracksProvider()

        guard !selectedTracks.isEmpty else { return }

        switch mode {
        case .create(let name):
            guard createTrackList(from: selectedTracks, withName: name) else { return }

        case .append(let trackListId):
            guard await appendTracks(selectedTracks, to: trackListId) else { return }
        }

        sheetManager.closeActive()
    }

    /// Создаёт новый треклист из выбранных треков.
    private func createTrackList(
        from selectedTracks: [LibraryTrack],
        withName name: String
    ) -> Bool {
        do {
            let created = try trackListsManager.createTrackList(
                from: selectedTracks,
                withName: name
            )
            toastManager.handle(.trackListCreated(name: created.name))
            return true
        } catch let appError as AppError {
            PersistentLogger.log("NewTrackListSelectionContainer: create tracklist failed error=\(appError)")
            toastManager.handle(appError)
            return false
        } catch {
            PersistentLogger.log("NewTrackListSelectionContainer: create tracklist failed error=\(error)")
            toastManager.handle(AppError.trackListSaveFailed)
            return false
        }
    }

    /// Добавляет выбранные треки в существующий треклист.
    private func appendTracks(
        _ selectedTracks: [LibraryTrack],
        to trackListId: UUID
    ) async -> Bool {
        let trackListName: String

        do {
            trackListName = try trackListsManager
                .loadTrackListMetas()
                .first { $0.id == trackListId }?
                .name ?? TrackListPresentationText.defaultTrackListName
        } catch let appError as AppError {
            toastManager.handle(appError)
            return false
        } catch {
            toastManager.handle(AppError.trackListLoadFailed)
            return false
        }

        do {
            let addedTracks = selectedTracks
            try trackListsManager.addTracks(
                selectedTracks,
                to: trackListId
            )
            await showAddedTracksToast(
                addedTracks,
                trackListName: trackListName
            )
            return true
        } catch let appError as AppError {
            PersistentLogger.log("NewTrackListSelectionContainer: add tracks failed error=\(appError)")
            toastManager.handle(appError)
            return false
        } catch {
            PersistentLogger.log("NewTrackListSelectionContainer: add tracks failed error=\(error)")
            toastManager.handle(AppError.trackListSaveFailed)
            return false
        }
    }

    /// Показывает один Toast по результату добавления треков.
    private func showAddedTracksToast(
        _ addedTracks: [LibraryTrack],
        trackListName: String
    ) async {
        if addedTracks.count == 1, let track = addedTracks.first {
            let event = await TrackToastEventBuilder.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
            toastManager.handle(event)
            return
        }

        toastManager.handle(
            .tracksAddedToTrackList(
                count: addedTracks.count,
                name: trackListName
            )
        )
    }
}
