//
//  TrackListViewModel.swift
//  TrackList
//
//  Состояние detail-flow одного треклиста и его реактивные presentation-данные.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class TrackListViewModel: ObservableObject {

    // MARK: - Состояние экрана

    /// Неизменяемый маршрут detail-экрана; master не передаёт в него устаревающий TrackList snapshot.
    let trackListId: UUID
    /// Контент различает первое чтение, корректно пустой список и ошибку загрузки.
    @Published private(set) var content: TrackListScreenContent = .loading

    // MARK: - Зависимости

    /// Читает согласованный снимок одного треклиста без передачи ViewModel mutation API.
    private let detailLoader: any TrackListDetailLoading
    /// Показывает ошибку initial/reload чтения, не участвуя в пользовательских mutation-командах.
    private let toastPresenter: any ToastPresenting
    /// Предоставляет invalidation-события, влияющие на detail presentation state.
    private let eventProvider: any TrackListEventProviding
    /// Даёт сохранённый presentation snapshot настроек строк.
    private let settingsManager: any SettingsManaging
    /// Предоставляет immutable playback snapshot для строк треклиста.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Предоставляет подтверждённый published snapshot идентификаторов «Избранного».
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Возвращает уже сохранённые runtime snapshot треков.
    private let runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding
    /// Строит runtime snapshot обычного локального трека.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// Возвращает SQLite-статистику отдельно от отображаемых строк.
    private let summaryProvider: any TrackCollectionSummaryProviding
    /// Читает сохранённые metadata локальных строк для prepared navigation targets.
    private let collectionMetadataLoader: any TrackCollectionMetadataLoading
    /// Собирает готовое состояние экрана из feature-local snapshots.
    private let screenStateBuilder = TrackListScreenStateBuilder()

    // MARK: - Загруженный detail snapshot

    /// Последнее успешно прочитанное имя; при reload failure оно не заменяется пустым значением.
    private(set) var name = ""
    /// Назначение треклиста определяет системный title и доступность rename list.
    private var kind: TrackListKind = .regular
    /// Последний успешно прочитанный состав и порядок строк треклиста.
    private(set) var tracks: [Track] = []
    /// Был ли хотя бы один согласованный detail snapshot успешно применён.
    private var hasLoadedDetail = false
    /// Несколько синхронных invalidation-сигналов объединяются в один detail reload.
    private var isDetailReloadScheduled = false

    // MARK: - Реактивные presentation snapshots

    /// Семантическая статистика заголовка, не зависящая от runtime snapshot строк.
    private var summary: TrackCollectionSummary?
    /// Последняя задача статистики отменяется при следующем релевантном invalidation.
    private var summaryTask: Task<Void, Never>?
    /// Идентификатор текущего TrackDisplayable; для Track это ID строки треклиста.
    private var currentTrackId: UUID?
    /// Контекст текущего воспроизведения.
    private var currentContext: PlaybackContext?
    /// Активно ли воспроизведение текущей строки.
    private var isPlaybackActive = false
    /// Идентификатор подсвеченной строки треклиста.
    private var highlightedRowId: UUID?
    /// Снимок «Избранного» из publisher хранится локально, чтобы builder не перечитывал потенциально старое свойство provider.
    private var favoriteTrackIds: Set<UUID>
    /// Последнее значение настройки чтения тегов после очистки metadata cache.
    private var lastTagReadingEnabled: Bool
    /// Последнее значение настройки показа формата файла.
    private var lastFileFormatVisible: Bool
    /// Консистентный snapshot настроек для каждого rebuild ScreenState.
    private var rowPresentationSettings: AppSettings
    /// Подготовленные metadata локальных треков для переходов к артисту и альбому.
    private var collectionNavigationTargetsByTrackId: [UUID: TrackCollectionNavigationTarget] = [:]
    /// Незавершённая batch-загрузка metadata отменяется при изменении состава треклиста.
    private var collectionNavigationTargetLoadTask: Task<Void, Never>?

    // MARK: - Runtime snapshot lifecycle

    /// Последние подтверждённые runtime snapshots ключуются physical trackId и используются всеми повторными строками.
    private var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]
    /// Для каждого physical trackId существует не более одного активного build-запроса.
    private var snapshotTasksByTrackId: [UUID: Task<Void, Never>] = [:]
    /// Локальное поколение не даёт отменённому, но уже завершившемуся build затереть каноничный update.
    private var snapshotGenerationByTrackId: [UUID: UInt] = [:]

    /// Combine-подписки принадлежат времени жизни detail feature, а не SwiftUI View.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    init(
        trackListId: UUID,
        detailLoader: any TrackListDetailLoading,
        toastPresenter: any ToastPresenting,
        eventProvider: any TrackListEventProviding,
        settingsManager: any SettingsManaging,
        playbackStateProvider: any PlaybackStateProviding,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        summaryProvider: any TrackCollectionSummaryProviding,
        collectionMetadataLoader: any TrackCollectionMetadataLoading
    ) {
        self.trackListId = trackListId
        self.detailLoader = detailLoader
        self.toastPresenter = toastPresenter
        self.eventProvider = eventProvider
        self.settingsManager = settingsManager
        self.playbackStateProvider = playbackStateProvider
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.runtimeSnapshotProvider = runtimeSnapshotProvider
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.summaryProvider = summaryProvider
        self.collectionMetadataLoader = collectionMetadataLoader
        self.favoriteTrackIds = favoriteTrackIdsProvider.favoriteTrackIds
        self.lastTagReadingEnabled = settingsManager.settings.visible.metadata.isTagReadingEnabled
        self.lastFileFormatVisible = settingsManager.settings.visible.library.isFileFormatVisible
        self.rowPresentationSettings = settingsManager.settings

        applyPlaybackState(playbackStateProvider.playbackState)
        observePresentationDependencies()
    }

    deinit {
        // После закрытия detail никакой поздний runtime/summary результат не должен публиковать UI state.
        summaryTask?.cancel()
        collectionNavigationTargetLoadTask?.cancel()
        snapshotTasksByTrackId.values.forEach { $0.cancel() }
    }

    // MARK: - Загрузка detail

    /// Выполняет initial read только один раз; повторная попытка разрешена после initial failure.
    func loadIfNeeded() {
        guard hasLoadedDetail == false else {
            return
        }

        loadDetail(isInitialLoad: true)
    }

    /// Повторяет только initial read после error/not-found presentation state.
    func retryInitialLoad() {
        guard hasLoadedDetail == false else {
            return
        }

        content = .loading
        loadDetail(isInitialLoad: true)
    }

    /// Перечитывает detail после invalidation, сохраняя последний успешный ScreenState при временной ошибке.
    private func reloadDetail() {
        guard hasLoadedDetail else {
            loadIfNeeded()
            return
        }

        loadDetail(isInitialLoad: false)
    }

    /// Применяет новый полный snapshot только после успешного чтения meta и строк одного ID.
    private func loadDetail(isInitialLoad: Bool) {
        do {
            applyLoadedDetail(try detailLoader.loadTrackList(id: trackListId))
        } catch let appError as AppError {
            applyDetailLoadFailure(appError, isInitialLoad: isInitialLoad)
        } catch {
            applyDetailLoadFailure(.trackListLoadFailed, isInitialLoad: isInitialLoad)
        }
    }

    /// Initial failure получает собственный content state, reload failure сохраняет последний успешный экран.
    private func applyDetailLoadFailure(
        _ error: AppError,
        isInitialLoad: Bool
    ) {
        if isInitialLoad {
            content = error == .trackListNotFound ? .notFound : .failed
        }

        toastPresenter.handle(error)
    }

    /// Сохраняет только актуальные runtime snapshots строк нового detail-снимка и отменяет удалённые задачи.
    private func applyLoadedDetail(_ detail: TrackList) {
        let currentTrackIds = Set(detail.tracks.map(\.trackId))
        let removedTrackIds = Set(tracks.map(\.trackId)).subtracting(currentTrackIds)

        for trackId in removedTrackIds {
            invalidateSnapshotRequest(for: trackId)
            snapshotsByTrackId.removeValue(forKey: trackId)
            collectionNavigationTargetsByTrackId.removeValue(forKey: trackId)
        }

        name = detail.name
        kind = detail.kind
        tracks = detail.tracks
        hasLoadedDetail = true
        rebuildScreenState()
        reloadSummary()
        reloadCollectionNavigationTargets()
    }

    // MARK: - Reactive subscriptions

    /// Подписывает ViewModel на presentation invalidations; пользовательские команды остаются в handlers.
    private func observePresentationDependencies() {
        playbackStateProvider.playbackStatePublisher
            .sink { [weak self] playbackState in
                Task { @MainActor in
                    self?.applyPlaybackState(playbackState)
                }
            }
            .store(in: &cancellables)

        favoriteTrackIdsProvider.favoriteTrackIdsPublisher
            .sink { [weak self] favoriteTrackIds in
                Task { @MainActor in
                    // Payload publisher является подтверждённым snapshot, даже если synchronous property provider ещё не обновилось.
                    self?.favoriteTrackIds = favoriteTrackIds
                    self?.rebuildScreenState()
                }
            }
            .store(in: &cancellables)

        eventProvider.trackDidUpdate
            .sink { [weak self] updateEvent in
                Task { @MainActor in
                    self?.applyTrackUpdateEvent(updateEvent)
                }
            }
            .store(in: &cancellables)

        eventProvider.appSettingsDidChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMetadataSettingsDidChange()
                }
            }
            .store(in: &cancellables)

        settingsManager.settingsPublisher
            .sink { [weak self] settings in
                Task { @MainActor in
                    self?.handleRowPresentationSettingsChange(settings)
                }
            }
            .store(in: &cancellables)

        eventProvider.trackListTracksDidChange
            .sink { [weak self] changedId in
                Task { @MainActor in
                    guard changedId == self?.trackListId else {
                        return
                    }

                    self?.scheduleDetailReload()
                }
            }
            .store(in: &cancellables)

        eventProvider.libraryDataDidChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard self?.hasLoadedDetail == true else {
                        return
                    }

                    // Синхронизация фонотеки может изменить сохранённый file_size строк detail.
                    self?.reloadSummary()
                }
            }
            .store(in: &cancellables)

        eventProvider.trackListsDidChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    // Rename и внешнее удаление должны читать тот же согласованный detail snapshot, что и initial load.
                    self?.scheduleDetailReload()
                }
            }
            .store(in: &cancellables)
    }

    /// Объединяет парные события сохранения строк и метаданных без параллельных reload одной детали.
    private func scheduleDetailReload() {
        guard isDetailReloadScheduled == false else {
            return
        }

        isDetailReloadScheduled = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isDetailReloadScheduled = false
            self.reloadDetail()
        }
    }

    // MARK: - Screen state

    /// Применяет immutable playback snapshot без перечитывания provider во время deferred rebuild.
    private func applyPlaybackState(_ playbackState: PlaybackStateSnapshot) {
        currentTrackId = playbackState.currentDisplayableId
        currentContext = playbackState.currentContext
        isPlaybackActive = playbackState.isPlaying
        rebuildScreenState()
    }

    /// Публикует loaded content только из согласованных feature-local snapshots.
    private func rebuildScreenState() {
        guard hasLoadedDetail else {
            return
        }

        content = .loaded(
            screenStateBuilder.build(
                id: trackListId,
                title: name,
                kind: kind,
                canRenameTrackList: kind.canRename,
                summary: summary,
                tracks: tracks,
                snapshotsByTrackId: snapshotsByTrackId,
                currentTrackId: currentTrackId,
                currentContext: currentContext,
                isPlaying: isPlaybackActive,
                highlightedRowId: highlightedRowId,
                favoriteTrackIds: favoriteTrackIds,
                settings: rowPresentationSettings,
                collectionNavigationTargetsByTrackId: collectionNavigationTargetsByTrackId
            )
        )
    }

    // MARK: - Prepared collection navigation

    /// Загружает metadata обычных локальных строк единым запросом, не читая их файлы.
    private func reloadCollectionNavigationTargets() {
        let trackIds = Set(
            tracks
                .filter { $0.source == .library }
                .map(\.trackId)
        )
        collectionNavigationTargetLoadTask?.cancel()

        collectionNavigationTargetLoadTask = Task { [weak self, collectionMetadataLoader] in
            let metadataByTrackId = await collectionMetadataLoader.cachedMetadata(
                forTrackIds: Array(trackIds)
            )
            guard Task.isCancelled == false,
                  let self,
                  Set(
                    self.tracks
                        .filter { $0.source == .library }
                        .map(\.trackId)
                  ) == trackIds else {
                return
            }

            self.collectionNavigationTargetsByTrackId = metadataByTrackId.reduce(
                into: [:]
            ) { targets, item in
                targets[item.key] = TrackCollectionNavigationTarget(metadata: item.value)
            }
            self.rebuildScreenState()
        }
    }

    // MARK: - Runtime snapshots

    /// Запрашивает runtime snapshot только для присутствующего обычного трека и не дублирует active build.
    func requestSnapshotIfNeeded(for trackId: UUID) {
        guard tracks.contains(where: {
            $0.trackId == trackId && $0.isPurchasedITunesRuntimeTrack == false
        }) else {
            return
        }
        guard snapshotsByTrackId[trackId] == nil,
              snapshotTasksByTrackId[trackId] == nil else {
            return
        }

        let generation = snapshotGenerationByTrackId[trackId, default: 0]
        let runtimeSnapshotProvider = runtimeSnapshotProvider
        let runtimeSnapshotBuilder = runtimeSnapshotBuilder

        snapshotTasksByTrackId[trackId] = Task { [weak self] in
            defer {
                if let self,
                   self.snapshotGenerationByTrackId[trackId, default: 0] == generation {
                    // Не оставляет завершившуюся неуспешную задачу вечной блокировкой следующего запроса.
                    self.snapshotTasksByTrackId.removeValue(forKey: trackId)
                }
            }

            let snapshot: TrackRuntimeSnapshot?

            if let storedSnapshot = runtimeSnapshotProvider.snapshot(forTrackId: trackId) {
                snapshot = storedSnapshot
            } else {
                do {
                    snapshot = try await runtimeSnapshotBuilder.buildSnapshot(forTrackId: trackId)
                } catch is CancellationError {
                    return
                } catch {
                    PersistentLogger.log("TrackListViewModel: runtime snapshot loading failed trackId=\(trackId) error=\(error)")
                    return
                }
            }

            guard Task.isCancelled == false,
                  let snapshot,
                  let self,
                  self.isCurrentSnapshotResult(trackId: trackId, generation: generation) else {
                return
            }

            self.snapshotsByTrackId[trackId] = snapshot
            self.rebuildScreenState()
        }
    }

    /// Обновление settings отменяет старые file reads до очистки локальных runtime snapshots.
    private func reloadSnapshotsAfterSettingsChange() {
        let localTrackIds = Set(
            tracks
                .filter { $0.isPurchasedITunesRuntimeTrack == false }
                .map(\.trackId)
        )

        for trackId in localTrackIds {
            invalidateSnapshotRequest(for: trackId)
        }

        snapshotsByTrackId.removeAll()
        rebuildScreenState()

        for trackId in localTrackIds {
            requestSnapshotIfNeeded(for: trackId)
        }
    }

    /// Делает прежний task неактуальным даже в случае позднего завершения после cancellation.
    private func invalidateSnapshotRequest(for trackId: UUID) {
        snapshotGenerationByTrackId[trackId, default: 0] &+= 1
        snapshotTasksByTrackId[trackId]?.cancel()
        snapshotTasksByTrackId.removeValue(forKey: trackId)
    }

    /// Проверяет поколение, присутствие physical track и наличие именно данного active task перед публикацией результата.
    private func isCurrentSnapshotResult(
        trackId: UUID,
        generation: UInt
    ) -> Bool {
        snapshotGenerationByTrackId[trackId, default: 0] == generation &&
        tracks.contains(where: {
            $0.trackId == trackId && $0.isPurchasedITunesRuntimeTrack == false
        })
    }

    // MARK: - Settings and track events

    /// Metadata-сигнал приходит после очистки общих cache, поэтому только он инвалидирует file snapshots.
    private func handleMetadataSettingsDidChange() {
        let settings = settingsManager.settings
        let isTagReadingEnabled = settings.visible.metadata.isTagReadingEnabled
        guard lastTagReadingEnabled != isTagReadingEnabled else {
            return
        }

        lastTagReadingEnabled = isTagReadingEnabled
        rowPresentationSettings = settings
        reloadSnapshotsAfterSettingsChange()
    }

    /// File-format меняет только готовую строку и не требует нового чтения runtime metadata.
    private func handleRowPresentationSettingsChange(_ settings: AppSettings) {
        rowPresentationSettings = settings

        let isFileFormatVisible = settings.visible.library.isFileFormatVisible
        guard lastFileFormatVisible != isFileFormatVisible else {
            return
        }

        lastFileFormatVisible = isFileFormatVisible
        rebuildScreenState()
    }

    /// Принимает каноничный event только для physical track, представленного в текущем detail snapshot.
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        guard tracks.contains(where: { $0.trackId == updateEvent.trackId }) else {
            return
        }

        // Каноничный snapshot имеет приоритет над любым прежним асинхронным file read.
        invalidateSnapshotRequest(for: updateEvent.trackId)
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
        rebuildScreenState()
        reloadCollectionNavigationTargets()

        guard updateEvent.changedFields.contains(.duration) else {
            return
        }

        reloadSummary()
    }

    // MARK: - Summary

    /// Перечитывает агрегаты независимо от строк, отменяя только предыдущий запрос этого detail ID.
    private func reloadSummary() {
        guard hasLoadedDetail else {
            return
        }

        summaryTask?.cancel()
        let summaryProvider = summaryProvider
        let trackListId = trackListId

        summaryTask = Task { [weak self] in
            do {
                let summary = try await summaryProvider.summaryForTrackList(trackListId: trackListId)
                guard Task.isCancelled == false,
                      let self,
                      self.trackListId == trackListId,
                      self.hasLoadedDetail else {
                    return
                }

                self.summary = summary
                self.rebuildScreenState()
            } catch is CancellationError {
                // Отмена ожидаема при следующем invalidation или закрытии detail.
            } catch {
                guard Task.isCancelled == false,
                      let self,
                      self.trackListId == trackListId else {
                    return
                }

                // Временная ошибка агрегатов не должна стирать последний успешно показанный summary.
                PersistentLogger.log("TrackListViewModel: summary loading failed trackListId=\(trackListId) error=\(error)")
            }
        }
    }
}

// MARK: - TrackListReading

extension TrackListViewModel: TrackListReading {
    /// Возвращает текущую строку по row identity, не смешивая её с physical trackId.
    func track(forRowId rowId: UUID) -> Track? {
        tracks.first { $0.id == rowId }
    }

    /// Возвращает подготовленный target без повторного чтения TrackRegistry в action handler.
    func collectionNavigationTarget(forRowId rowId: UUID) -> TrackCollectionNavigationTarget? {
        guard let track = track(forRowId: rowId) else {
            return nil
        }

        return collectionNavigationTargetsByTrackId[track.trackId]
    }

    /// Возвращает runtime snapshot, нужный rename handler для построения точного request.
    func runtimeSnapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }
}
