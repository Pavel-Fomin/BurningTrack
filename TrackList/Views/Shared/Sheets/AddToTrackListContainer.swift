//
//  AddToTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана добавления трека или выбранных треков в треклист.
//
//  Контейнер выполняет роль координатора:
//  - владеет состоянием выбора (selectedTrackListId)
//  - принимает контекст открытия sheet’а (sourceTrackListId)
//  - управляет кнопками navigation bar (✓ / ×)
//  - выполняет бизнес-команду добавления треков
//
//  ВАЖНО:
//  - контейнер не содержит UI-разметки списка
//  - контейнер не реагирует на tap’ы напрямую
//  - вся визуальная логика вынесена в AddToTrackListSheet
//  - sheet не знает о командах и навигации
//
//  Архитектурный паттерн:
//  NavigationBarHost (UIKit) + чистый SwiftUI sheet
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct AddToTrackListContainer: View {

    // MARK: - Input

    /// Данные, переданные через SheetManager
    let data: AddToTrackListSheetData

    // MARK: - State

    /// Выбранный пользователем треклист назначения
    @State private var selectedTrackListId: UUID?

    // MARK: - Data source

    /// Список всех треклистов в фиксированном порядке
    private let trackLists: [TrackListsManager.TrackListMeta]

    init(data: AddToTrackListSheetData) {
        self.data = data

        do {
            self.trackLists = try TrackListsManager.shared
                .loadTrackListMetas()
                .sorted { $0.createdAt > $1.createdAt }
        } catch let appError as AppError {
            self.trackLists = []
            ToastManager.shared.handle(appError)
        } catch {
            self.trackLists = []
            ToastManager.shared.handle(AppError.trackListLoadFailed)
        }
    }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Добавить в треклист",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только если:
            /// - выбран треклист
            /// - он отличается от исходного
            isRightEnabled: Binding(
                get: {
                    selectedTrackListId != nil &&
                    selectedTrackListId != data.sourceTrackListId
                },
                set: { _ in }
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                SheetManager.shared.closeActive()
            },

            /// Подтверждение добавления трека или batch-выбора
            onRightTap: {
                Task { await addTracks() }
            }
        ) {
            /// Чистый UI-компонент без логики
            AddToTrackListSheet(
                trackLists: trackLists,
                currentTrackListId: data.sourceTrackListId,
                selectedTrackListId: $selectedTrackListId
            )
        }
    }

    // MARK: - Actions

    /// Добавляет один трек или batch-выбор в выбранный треклист.
    private func addTracks() async {
        guard let trackListId = selectedTrackListId else { return }
        guard !data.trackIds.isEmpty else { return }

        do {
            if let libraryBatchTracks = data.libraryBatchTracks {
                try await addLibraryBatchTracks(
                    libraryBatchTracks,
                    to: trackListId
                )
            } else if let purchasedITunesTracks = purchasedITunesTracks() {
                try await AppCommandExecutor.shared.addPurchasedITunesTracksToTrackList(
                    purchasedITunesTracks,
                    trackListId: trackListId
                )
            } else if data.trackIds.count == 1, let trackId = data.trackIds.first {
                try await AppCommandExecutor.shared.addTrackToTrackList(
                    trackId: trackId,
                    trackListId: trackListId
                )
            } else {
                try await AppCommandExecutor.shared.addTracksToTrackList(
                    trackIds: data.trackIds,
                    trackListId: trackListId
                )
            }
            SheetManager.shared.closeActive()
        } catch let appError as AppError {
            print("❌ Ошибка добавления трека в треклист: \(appError)")
            ToastManager.shared.handle(appError)
        } catch {
            print("❌ Ошибка добавления трека в треклист: \(error)")
            ToastManager.shared.handle(AppError.trackListSaveFailed)
        }
    }

    /// Возвращает iTunes-треки, если sheet был открыт именно для этого источника.
    private func purchasedITunesTracks() -> [PurchasedITunesPlayableTrack]? {
        let tracks = data.tracks.compactMap {
            $0.asPurchasedITunesPlayableTrack()
        }

        guard !tracks.isEmpty,
              tracks.count == data.tracks.count
        else {
            return nil
        }

        return tracks
    }

    /// Добавляет batch из фонотеки через существующий manager треклистов.
    private func addLibraryBatchTracks(
        _ tracks: [LibraryTrack],
        to trackListId: UUID
    ) async throws {
        guard !tracks.isEmpty else { return }

        let trackListName = trackListName(for: trackListId)

        try TrackListsManager.shared.addTracks(
            tracks,
            to: trackListId
        )

        await showAddedLibraryTracksToast(
            tracks,
            trackListName: trackListName
        )
    }

    /// Возвращает имя треклиста для итогового toast.
    private func trackListName(for trackListId: UUID) -> String {
        trackLists.first { $0.id == trackListId }?.name ?? "Треклист"
    }

    /// Показывает один итоговый toast для batch-добавления.
    private func showAddedLibraryTracksToast(
        _ tracks: [LibraryTrack],
        trackListName: String
    ) async {
        if tracks.count == 1, let track = tracks.first {
            let event = await TrackToastEventBuilder.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
            ToastManager.shared.handle(event)
            return
        }

        ToastManager.shared.handle(
            .tracksAddedToTrackList(
                count: tracks.count,
                name: trackListName
            )
        )
    }
}
