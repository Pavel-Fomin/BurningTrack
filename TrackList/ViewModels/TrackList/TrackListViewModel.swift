//
//  TrackListViewModel.swift
//  TrackList
//
//  Управляет одним треклистом:
//  - загрузка треков по ID
//  - сохранение треков
//  - перемещение
//  - удаление
//  - переименование файлов треков
//
//  Created by Pavel Fomin on 28.04.2025.
//


import Foundation
import SwiftUI
import Combine

@MainActor
final class TrackListViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var tracks: [Track] = []
    @Published var currentListId: UUID?
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime snapshot треков по id
    /// Готовое состояние экрана одного треклиста.
    @Published private(set) var screenState: TrackListScreenState?

    /// Запускает общий rename-flow файлов треков.
    private let fileRenamer: any TrackFileRenaming
    /// Управляет содержимым одного треклиста.
    private let trackListManager: any TrackListManaging
    /// Управляет списком треклистов.
    private let trackListsManager: any TrackListsManaging
    /// Показывает пользовательские сообщения.
    private let toastPresenter: any ToastPresenting
    /// Выполняет команды изменения одного треклиста.
    private let commandExecutor: any TrackListCommandExecuting
    /// Предоставляет события, влияющие на экран одного треклиста.
    private let eventProvider: any TrackListEventProviding
    /// Предоставляет playback-состояние без прямой подписки View на PlayerViewModel.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Предоставляет сохранённые runtime snapshot треков.
    private let runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding
    /// Создаёт runtime snapshot треков.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// Собирает готовое состояние экрана одного треклиста.
    private let screenStateBuilder = TrackListScreenStateBuilder()
    /// Идентификатор текущего TrackDisplayable; для Track это id строки треклиста.
    private var currentTrackId: UUID?
    /// Контекст текущего воспроизведения.
    private var currentContext: PlaybackContext?
    /// Активно ли воспроизведение текущей строки.
    private var isPlaybackActive: Bool = false
    /// Идентификатор подсвеченной строки треклиста.
    private var highlightedRowId: UUID?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    
    init(
        trackList: TrackList,
        fileRenamer: any TrackFileRenaming,
        trackListManager: any TrackListManaging,
        trackListsManager: any TrackListsManaging,
        toastPresenter: any ToastPresenting,
        commandExecutor: any TrackListCommandExecuting,
        eventProvider: any TrackListEventProviding,
        playbackStateProvider: any PlaybackStateProviding,
        runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    ) {
        self.fileRenamer = fileRenamer
        self.trackListManager = trackListManager
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.commandExecutor = commandExecutor
        self.eventProvider = eventProvider
        self.playbackStateProvider = playbackStateProvider
        self.runtimeSnapshotProvider = runtimeSnapshotProvider
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.currentListId = trackList.id
        self.name = trackList.name
        self.tracks = trackList.tracks
        applyPlaybackState(playbackStateProvider.playbackState)

        playbackStateProvider.playbackStatePublisher
            .sink { [weak self] playbackState in
                guard let self else { return }

                Task { @MainActor in
                    self.applyPlaybackState(playbackState)
                }
            }
            .store(in: &cancellables)
        
        eventProvider.trackDidUpdate
            .sink { [weak self] updateEvent in
                guard let self else { return }
                
                Task { @MainActor in
                    self.applyTrackUpdateEvent(updateEvent)
                }
            }
            .store(in: &cancellables)
        
        eventProvider.appSettingsDidChange
            .sink { [weak self] _ in
                guard let self else { return }
                
                Task { @MainActor in
                    self.reloadSnapshotsAfterSettingsChange()
                }
            }
            .store(in: &cancellables)
        
        eventProvider.trackListTracksDidChange
            .sink { [weak self] changedId in
                guard let self else { return }
                
                Task { @MainActor in
                    guard changedId == self.currentListId else { return }
                    
                    self.loadTracks()
                }
            }
            .store(in: &cancellables)
        
        eventProvider.trackListsDidChange
            .sink { [weak self] _ in
                guard let self else { return }
                
                Task { @MainActor in
                    self.refreshMeta()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Rename

    /// Запускает сценарий переименования файла трека из треклиста.
    func renameTrack(
        rowId: UUID,
        strategy: FileRenameStrategy
    ) {
        guard let track = tracks.first(where: { $0.id == rowId }) else {
            return
        }
        guard canRename(track) else { return }

        let snapshot = snapshotsByTrackId[track.trackId]
        let request = TrackFileRenameRequest(
            trackId: track.trackId,
            rowId: track.id,
            currentFileName: snapshot?.fileName ?? track.fileName,
            artist: snapshot?.artist,
            title: snapshot?.title,
            strategy: strategy
        )
        fileRenamer.handle(request)
    }

    /// Проверяет, можно ли запускать файловое переименование для строки треклиста.
    private func canRename(
        _ track: Track
    ) -> Bool {
        guard track.isPurchasedITunesRuntimeTrack else {
            return true
        }

        toastPresenter.handle(
            .operationFailed(message: "Это действие недоступно для iTunes-трека")
        )
        return false
    }

    // MARK: - Loading

    func loadTracks() {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран")
            return
        }

        do {
            let loadedTracks = try trackListManager.loadTracks(for: id)
            self.tracks = loadedTracks
            rebuildScreenState()
            print("📥 Загружено \(tracks.count) треков из треклиста \(id)")
        } catch let appError as AppError {
            tracks = []
            rebuildScreenState()
            toastPresenter.handle(appError)
        } catch {
            tracks = []
            rebuildScreenState()
            toastPresenter.handle(AppError.trackListLoadFailed)
        }
    }


    // MARK: - Save

    private func save() -> Bool {
        guard let id = currentListId else { return false }

        let didSave = trackListManager.saveTracks(tracks, for: id)
        if !didSave {
            PersistentLogger.log("TrackListViewModel: saveTracks failed id=\(id)")
        }
        return didSave
    }

    // MARK: - Screen State

    /// Применяет playback-состояние к локальному состоянию экрана.
    private func applyPlaybackState(_ playbackState: PlaybackState) {
        currentTrackId = playbackState.currentDisplayableId
        currentContext = playbackState.currentContext
        isPlaybackActive = playbackState.isPlaying

        rebuildScreenState()
    }

    /// Пересобирает готовое состояние экрана одного треклиста.
    private func rebuildScreenState() {
        guard let id = currentListId else {
            screenState = nil
            return
        }

        screenState = screenStateBuilder.build(
            id: id,
            title: name,
            tracks: tracks,
            snapshotsByTrackId: snapshotsByTrackId,
            currentTrackId: currentTrackId,
            currentContext: currentContext,
            isPlaying: isPlaybackActive,
            highlightedRowId: highlightedRowId
        )
    }
    
    
    // MARK: - Snapshot

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        guard !tracks.contains(where: { track in
            track.trackId == trackId &&
            track.isPurchasedITunesRuntimeTrack
        }) else {
            return
        }

        if snapshotsByTrackId[trackId] != nil { return }
        
        let runtimeSnapshotProvider = runtimeSnapshotProvider
        let runtimeSnapshotBuilder = runtimeSnapshotBuilder

        Task {
            let snapshot: TrackRuntimeSnapshot?

            if let storedSnapshot = runtimeSnapshotProvider.snapshot(forTrackId: trackId) {
                snapshot = storedSnapshot
            } else {
                snapshot = await runtimeSnapshotBuilder.buildSnapshot(forTrackId: trackId)
            }

            guard let snapshot else { return }

            await MainActor.run {
                snapshotsByTrackId[trackId] = snapshot
                rebuildScreenState()
            }
        }
    }

    /// Пересобирает runtime snapshot загруженных треков после изменения настроек приложения.
    private func reloadSnapshotsAfterSettingsChange() {
        snapshotsByTrackId.removeAll()
        for track in tracks {
            requestSnapshotIfNeeded(for: track.trackId)
        }
    }

    /// Применяет единое событие обновления трека к состоянию треклиста.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
        rebuildScreenState()
    }

    // MARK: - Reorder

    func moveTrack(from source: IndexSet, to destination: Int) {
        let previousTracks = tracks
        tracks.move(fromOffsets: source, toOffset: destination)
        rebuildScreenState()
        guard save() else {
            tracks = previousTracks
            rebuildScreenState()
            toastPresenter.handle(AppError.trackListSaveFailed)
            return
        }
        print("↕️ Порядок треков обновлён и сохранён")
    }


    // MARK: - Remove

    func removeTrack(at offsets: IndexSet) {
        guard
            let index = offsets.first,
            let listId = currentListId
        else { return }

        let listItemId = tracks[index].id

        Task {
            do {
                try await commandExecutor.removeTrackFromTrackList(
                    listItemId: listItemId,
                    trackListId: listId
                )
            } catch let appError as AppError {
                await MainActor.run {
                    toastPresenter.handle(appError)
                }
            } catch {
                await MainActor.run {
                    toastPresenter.handle(AppError.trackListSaveFailed)
                }
            }
        }
    }

 
    // MARK: - Refresh meta

    func refreshMeta() {
        guard let id = currentListId else { return }

        let metas: [TrackListMeta]
        do {
            metas = try trackListsManager.loadTrackListMetas()
        } catch let appError as AppError {
            toastPresenter.handle(appError)
            return
        } catch {
            toastPresenter.handle(AppError.trackListLoadFailed)
            return
        }

        guard let meta = metas.first(where: { $0.id == id }) else { return }

        if name != meta.name {
            name = meta.name
            rebuildScreenState()
        }
    }
}
