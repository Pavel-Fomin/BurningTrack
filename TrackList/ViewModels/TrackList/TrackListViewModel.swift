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
    /// Даёт snapshot настроек, влияющих на отображение строк треклиста.
    private let settingsManager: any SettingsManaging
    /// Предоставляет playback-состояние без прямой подписки View на PlayerViewModel.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Предоставляет сохранённые runtime snapshot треков.
    private let runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding
    /// Создаёт runtime snapshot треков.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// Получает SQLite-статистику отдельно от массива отображаемых строк.
    private let summaryProvider: any TrackCollectionSummaryProviding
    /// Собирает готовое состояние экрана одного треклиста.
    private let screenStateBuilder = TrackListScreenStateBuilder()
    /// Готовый вторичный текст заголовка, не зависящий от runtime snapshot строк.
    private var summaryText: String?
    /// Незавершённый запрос статистики, который отменяется при следующем релевантном событии.
    private var summaryTask: Task<Void, Never>?
    /// Пропускает собственное событие сохранения перестановки, не меняющее итоговые суммы.
    private var skipsNextTrackListTracksChangeAfterReorder = false
    /// Идентификатор текущего TrackDisplayable; для Track это id строки треклиста.
    private var currentTrackId: UUID?
    /// Контекст текущего воспроизведения.
    private var currentContext: PlaybackContext?
    /// Активно ли воспроизведение текущей строки.
    private var isPlaybackActive: Bool = false
    /// Идентификатор подсвеченной строки треклиста.
    private var highlightedRowId: UUID?
    /// Последнее значение настройки чтения тегов, ожидающее metadata-сигнал после очистки кэшей.
    private var lastTagReadingEnabled: Bool
    /// Последнее значение настройки отображения формата файла.
    private var lastFileFormatVisible: Bool
    /// Снимок настроек для консистентной сборки presentation state строк.
    private var rowPresentationSettings: AppSettings

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
        settingsManager: any SettingsManaging,
        playbackStateProvider: any PlaybackStateProviding,
        runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        summaryProvider: any TrackCollectionSummaryProviding
    ) {
        self.fileRenamer = fileRenamer
        self.trackListManager = trackListManager
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.commandExecutor = commandExecutor
        self.eventProvider = eventProvider
        self.settingsManager = settingsManager
        self.playbackStateProvider = playbackStateProvider
        self.runtimeSnapshotProvider = runtimeSnapshotProvider
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.summaryProvider = summaryProvider
        self.lastTagReadingEnabled = settingsManager.settings.visible.metadata.isTagReadingEnabled
        self.lastFileFormatVisible = settingsManager.settings.visible.library.isFileFormatVisible
        self.rowPresentationSettings = settingsManager.settings
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
                    self.handleMetadataSettingsDidChange()
                }
            }
            .store(in: &cancellables)

        // Лёгкое изменение формата файла пересобирает только presentation state текущего треклиста.
        settingsManager.settingsPublisher
            .sink { [weak self] settings in
                Task { @MainActor in
                    self?.handleRowPresentationSettingsChange(settings)
                }
            }
            .store(in: &cancellables)
        
        eventProvider.trackListTracksDidChange
            .sink { [weak self] changedId in
                guard let self else { return }
                
                Task { @MainActor in
                    guard changedId == self.currentListId else { return }

                    if self.skipsNextTrackListTracksChangeAfterReorder {
                        self.skipsNextTrackListTracksChangeAfterReorder = false
                        return
                    }

                    self.loadTracks()
                    self.reloadSummary()
                }
            }
            .store(in: &cancellables)

        eventProvider.libraryDataDidChange
            .sink { [weak self] _ in
                guard let self else { return }

                Task { @MainActor in
                    // Синхронизация может обновить file_size треков, уже входящих в этот треклист.
                    self.reloadSummary()
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

        reloadSummary()
    }

    deinit {
        // Результат отменённого агрегирующего запроса не нужен после закрытия экрана.
        summaryTask?.cancel()
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
            .operationFailed(
                message: PlayerPresentationText.purchasedITunesActionUnavailableMessage
            )
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
            summaryText: summaryText,
            tracks: tracks,
            snapshotsByTrackId: snapshotsByTrackId,
            currentTrackId: currentTrackId,
            currentContext: currentContext,
            isPlaying: isPlaybackActive,
            highlightedRowId: highlightedRowId,
            settings: rowPresentationSettings
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
                snapshot = try? await runtimeSnapshotBuilder.buildSnapshot(forTrackId: trackId)
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
        rebuildScreenState()
        for track in tracks {
            requestSnapshotIfNeeded(for: track.trackId)
        }
    }

    /// Реагирует на единственное общее событие, которое означает изменение runtime metadata трека.
    private func handleMetadataSettingsDidChange() {
        let settings = settingsManager.settings
        let isTagReadingEnabled = settings.visible.metadata.isTagReadingEnabled
        guard lastTagReadingEnabled != isTagReadingEnabled else { return }

        lastTagReadingEnabled = isTagReadingEnabled
        // Metadata-сигнал приходит после очистки кэшей, поэтому фиксируем согласованный snapshot для строк.
        rowPresentationSettings = settings
        reloadSnapshotsAfterSettingsChange()
    }

    /// Применяет только настройку, меняющую готовые строки без чтения metadata и artwork.
    private func handleRowPresentationSettingsChange(_ settings: AppSettings) {
        rowPresentationSettings = settings

        let isFileFormatVisible = settings.visible.library.isFileFormatVisible
        guard lastFileFormatVisible != isFileFormatVisible else { return }

        lastFileFormatVisible = isFileFormatVisible
        rebuildScreenState()
    }

    /// Применяет единое событие обновления трека к состоянию треклиста.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
        rebuildScreenState()

        // Runtime snapshot без новой длительности не меняет итоговую статистику треклиста.
        guard updateEvent.changedFields.contains(.duration),
              tracks.contains(where: { $0.trackId == updateEvent.trackId }) else {
            return
        }

        reloadSummary()
    }

    // MARK: - Summary

    /// Загружает статистику отдельно от строк и применяет только результат текущего треклиста.
    private func reloadSummary() {
        guard let trackListId = currentListId else { return }

        summaryTask?.cancel()
        let summaryProvider = summaryProvider

        summaryTask = Task { [weak self] in
            do {
                let summary = try await summaryProvider.summaryForTrackList(trackListId: trackListId)
                guard Task.isCancelled == false,
                      let self,
                      self.currentListId == trackListId else {
                    return
                }

                self.summaryText = TrackCollectionSummaryFormatter.string(from: summary)
                self.rebuildScreenState()
            } catch is CancellationError {
                // Отмена ожидаема при новом составе треклиста или закрытии экрана.
            } catch {
                guard Task.isCancelled == false,
                      let self,
                      self.currentListId == trackListId else {
                    return
                }

                // Не показываем отдельный toast, чтобы ошибка статистики не блокировала экран треклиста.
                PersistentLogger.log("TrackListViewModel: summary loading failed trackListId=\(trackListId) error=\(error)")
                self.summaryText = nil
                self.rebuildScreenState()
            }
        }
    }

    // MARK: - Reorder

    func moveTrack(from source: IndexSet, to destination: Int) {
        let previousTracks = tracks
        tracks.move(fromOffsets: source, toOffset: destination)
        rebuildScreenState()

        // saveTracks публикует общий event, но перестановка не меняет состав, длительность и размер.
        skipsNextTrackListTracksChangeAfterReorder = true
        guard save() else {
            skipsNextTrackListTracksChangeAfterReorder = false
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
