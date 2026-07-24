//
//  PlayerScreenViewModel.swift
//  TrackList
//
//  Экранная ViewModel раздела "Плеер".
//
//  Created by Codex on 13.06.2026.
//

import Foundation
import Combine

/// Экранная ViewModel раздела "Плеер".
///
/// Отвечает за состояние высокоуровневого экрана плеера
/// и передачу пользовательских действий в PlayerFlowActionHandler.
///
/// Не управляет AVPlayer напрямую.
/// Не выполняет файловые операции напрямую.
/// Не открывает sheet напрямую.
/// Не показывает toast напрямую.
@MainActor
final class PlayerScreenViewModel: ObservableObject {

    // MARK: - State

    /// Готовое состояние экрана плеера.
    @Published private(set) var state: PlayerScreenState

    // MARK: - Dependencies

    /// ViewModel воспроизведения.
    private let playerViewModel: PlayerViewModel

    /// Обработчик пользовательских действий экрана плеера.
    private let actionHandler: PlayerFlowActionHandler

    /// Менеджер sheet-состояния.
    private let sheetManager: SheetManager

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Менеджер настроек приложения.
    private let appSettingsManager: AppSettingsManager

    /// Builder состояния строк плеера.
    private let rowStateBuilder: PlayerTrackRowStateBuilder

    /// Подписки экранной ViewModel.
    private var cancellables = Set<AnyCancellable>()

    /// Последняя известная очередь плеера.
    private var currentTracks: [PlayerTrack] = []
    /// Сохранённые metadata текущей очереди, доступные для перехода к музыкальной коллекции.
    private var collectionNavigationTargetsByTrackId: [UUID: TrackCollectionNavigationTarget] = [:]
    /// Набор локальных треков, для которого уже запрошены сохранённые metadata.
    private var collectionNavigationTargetTrackIds = Set<UUID>()
    /// Незавершённая загрузка metadata отменяется при изменении состава очереди.
    private var collectionNavigationTargetLoadTask: Task<Void, Never>?

    // MARK: - Инициализация

    init(
        playerViewModel: PlayerViewModel,
        actionHandler: PlayerFlowActionHandler,
        sheetManager: SheetManager,
        playlistManager: PlaylistManager,
        appSettingsManager: AppSettingsManager,
        rowStateBuilder: PlayerTrackRowStateBuilder
    ) {
        self.playerViewModel = playerViewModel
        self.actionHandler = actionHandler
        self.sheetManager = sheetManager
        self.playlistManager = playlistManager
        self.appSettingsManager = appSettingsManager
        self.rowStateBuilder = rowStateBuilder
        self.state = PlayerScreenState(
            rows: [],
            scrollTargetId: nil,
            trackCount: 0,
            canExport: false,
            canClear: false
        )
        observePlaylist()
        observePlaybackState()
        observeSnapshots()
        observeDisplaySettings()
        observeHighlightedRow()
    }

    // MARK: - Actions

    /// Передаёт пользовательское действие в обработчик Player Flow.
    func handle(_ action: PlayerScreenAction) {
        actionHandler.handle(action)
    }

    /// Пересобирает состояние экрана плеера из текущей очереди.
    func updateTracks(
        _ tracks: [PlayerTrack],
        reloadCollectionNavigationTargets: Bool = false
    ) {
        currentTracks = tracks
        if reloadCollectionNavigationTargets {
            loadCollectionNavigationTargetsIfNeeded(for: tracks)
        }

        rebuildState()
    }

    /// Пересобирает состояние списка с уже загруженными сохранёнными metadata.
    private func rebuildState() {
        let tracks = currentTracks
        let shouldShowTags = appSettingsManager.settings.visible.metadata.isTagReadingEnabled
        let shouldShowFileFormat = appSettingsManager.settings.visible.library.isFileFormatVisible
        let currentQueueItemId = currentPlayerQueueItemId(in: tracks)
        let rows = rowStateBuilder.makeRows(
            tracks: tracks,
            currentQueueItemId: currentQueueItemId,
            isPlaying: playerViewModel.isPlaying,
            snapshotsByTrackId: playerViewModel.snapshotsByTrackId,
            collectionNavigationTargetsByTrackId: collectionNavigationTargetsByTrackId,
            highlightedRowId: sheetManager.highlightedRowID,
            shouldShowTags: shouldShowTags,
            shouldShowFileFormat: shouldShowFileFormat
        )
        state = PlayerScreenState(
            rows: rows,
            scrollTargetId: currentQueueItemId,
            trackCount: tracks.count,
            canExport: !tracks.isEmpty,
            canClear: !tracks.isEmpty
        )
    }

    /// Загружает сохранённые metadata только для обычных локальных треков очереди.
    private func loadCollectionNavigationTargetsIfNeeded(
        for tracks: [PlayerTrack]
    ) {
        let trackIds = Set(
            tracks
                .filter { $0.source == .library }
                .map(\.trackId)
        )
        guard trackIds != collectionNavigationTargetTrackIds else { return }

        collectionNavigationTargetTrackIds = trackIds
        collectionNavigationTargetLoadTask?.cancel()

        collectionNavigationTargetLoadTask = Task { [weak self] in
            let metadataByTrackId = await TrackRegistry.shared.cachedMetadata(
                forTrackIds: Array(trackIds)
            )
            guard Task.isCancelled == false,
                  let self,
                  self.collectionNavigationTargetTrackIds == trackIds else {
                return
            }

            self.collectionNavigationTargetsByTrackId = metadataByTrackId.reduce(
                into: [:]
            ) { targets, item in
                targets[item.key] = TrackCollectionNavigationTarget(
                    metadata: item.value
                )
            }
            self.rebuildState()
        }
    }

    /// Наблюдает за очередью плеера и пересобирает состояние экрана.
    private func observePlaylist() {
        playlistManager.$tracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                self?.updateTracks(
                    tracks,
                    reloadCollectionNavigationTargets: true
                )
            }
            .store(in: &cancellables)
        updateTracks(
            playlistManager.tracks,
            reloadCollectionNavigationTargets: true
        )
    }

    /// Наблюдает за состоянием воспроизведения и обновляет строки плеера.
    private func observePlaybackState() {
        playerViewModel.$currentTrackDisplayable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTracks(self.currentTracks)
            }
            .store(in: &cancellables)
        playerViewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTracks(self.currentTracks)
            }
            .store(in: &cancellables)
        playerViewModel.$currentContext
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTracks(self.currentTracks)
            }
            .store(in: &cancellables)
    }

    /// Наблюдает за runtime snapshot треков и обновляет строки плеера.
    private func observeSnapshots() {
        playerViewModel.$snapshotsByTrackId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTracks(self.currentTracks)
            }
            .store(in: &cancellables)
    }

    /// Обновляет строки плеера только при изменении отображаемых в них полей.
    private func observeDisplaySettings() {
        appSettingsManager.settingsPublisher
        .removeDuplicates { previous, current in
            previous.visible.metadata.isTagReadingEnabled == current.visible.metadata.isTagReadingEnabled &&
            previous.visible.library.isFileFormatVisible == current.visible.library.isFileFormatVisible
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            self.updateTracks(self.currentTracks)
        }
        .store(in: &cancellables)
    }

    /// Наблюдает за выделенной строкой, связанной с активным sheet.
    private func observeHighlightedRow() {
        sheetManager.$highlightedRowID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTracks(self.currentTracks)
            }
            .store(in: &cancellables)
    }

    /// Возвращает идентификатор текущего элемента очереди плеера.
    private func currentPlayerQueueItemId(in tracks: [PlayerTrack]) -> UUID? {
        guard playerViewModel.currentContext == .player else { return nil }
        guard let current = playerViewModel.currentTrackDisplayable else { return nil }
        return tracks.first(where: { $0.id == current.id })?.id
    }
}
