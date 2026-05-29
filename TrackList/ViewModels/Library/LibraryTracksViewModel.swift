//
//  LibraryTracksViewModel.swift
//  TrackList
//
//  ViewModel для треков внутри папки
//  Отвечает за данные треков и операции над ними
//
//  Created by Pavel Fomin on 12.12.2025.
//

import Foundation
import SwiftUI
import Combine

/// Ограничивает количество одновременно выполняемых задач.
/// Нужен для безопасной загрузки metadata большого количества файлов.
private actor AsyncLimiter {
    private let limit: Int
    private var running = 0

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        while running >= limit {
            await Task.yield()
        }

        running += 1
    }

    func release() {
        running -= 1
    }
}

@MainActor
final class LibraryTracksViewModel: ObservableObject, TrackMetadataProviding {

    // MARK: - Входные данные

    let folderURL: URL
    let folderId: UUID

    // MARK: - Состояния

    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime-снимки треков по id
    @Published var bulkSelection = BulkSelectionState<UUID, BulkTrackAction>()
    @Published private(set) var batchFilenameRenameFlow = BatchFilenameRenameFlow()
    @Published var isLoading = false
    @Published private(set) var didLoad = false
    
    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    private var cancellables = Set<AnyCancellable>()

    /// Общее количество треков в текущих секциях.
    var totalVisibleTrackCount: Int {
        trackSections.reduce(0) { result, section in
            result + section.tracks.count
        }
    }

    /// Показывает, выбраны ли все видимые треки.
    var areAllVisibleTracksSelected: Bool {
        totalVisibleTrackCount > 0 && bulkSelection.selectedCount == totalVisibleTrackCount
    }

    // MARK: - Init

    init(
        folderURL: URL,
        tracksProvider: LibraryTracksProvider = FastLibraryTracksProvider(),
        badgeProvider: TrackListBadgeProvider = DefaultTrackListBadgeProvider()
    ) {
        self.folderURL = folderURL
        self.folderId = folderURL.libraryFolderId

        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider

        bindBatchFilenameRenameFlow()

        NotificationCenter.default.addObserver(
            forName: .trackDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let updateEvent = notification.object as? TrackUpdateEvent else { return }

            Task { @MainActor in
                self.applyTrackUpdateEvent(updateEvent)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .trackBatchDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let events = notification.userInfo?["events"] as? [TrackUpdateEvent] else { return }

            Task { @MainActor in
                self.applyTrackUpdateEvents(events)
            }
        }

        NotificationCenter.default.publisher(for: .appSettingsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.reloadSnapshotsAfterSettingsChange()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .trackListsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reloadTrackListBadges()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .trackListTracksDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reloadTrackListBadges()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load

    /// Пробрасывает изменения flow наружу для подписчиков ViewModel.
    private func bindBatchFilenameRenameFlow() {
        batchFilenameRenameFlow.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func loadTracksIfNeeded() async {
        // Если уже загружали — ничего не делаем
        if didLoad {return}
        didLoad = true

        await refresh()
    }

    // MARK: - Refresh

    /// Явное обновление данных.
    /// Вызывается строго из UX-слоя.
    func refresh() async {
        if isLoading {return}

        isLoading = true
        defer { isLoading = false }

        await loadInitialTracks()

        Task { [weak self] in
            guard let self else { return }
            await self.loadDetailsInBackground()
        }
    }
    
    /// Быстро загружает первичный список треков без синхронизации и дополнительных деталей.
    private func loadInitialTracks() async {
        let tracks = await tracksProvider.tracks(inFolder: folderId)

        trackSections = TrackSectionBuilder.build(
            from: tracks,
            mode: .date
        )
    }

    /// Догружает тяжёлые детали после появления первичного списка.
    private func loadDetailsInBackground() async {
        reloadTrackListBadges()

        await MusicLibraryManager.shared.syncFolderIfNeeded(folderId: folderId)

        await updateAvailabilityInBackground()
    }

    // MARK: - Badges

    /// Обновляет бейджи треклистов для уже загруженных треков.
    /// Не перезагружает сами треки и не меняет секции.
    private func reloadTrackListBadges() {
        let ids = trackSections.flatMap { $0.tracks }.map { $0.trackId }
        trackListNamesById = badgeProvider.badges(for: ids)
    }

    // MARK: - Bulk Selection

    /// Включает режим массового выбора без заранее выбранного действия.
    func activateBulkSelection() {
        bulkSelection.activate()
    }

    /// Сбрасывает режим массового выбора и текущий selection.
    func resetBulkSelection() {
        bulkSelection.reset()
    }

    /// Выбирает все видимые треки или снимает выбор со всех, если уже выбраны все.
    func toggleSelectAllVisibleTracks() {
        guard bulkSelection.isActive else { return }

        if areAllVisibleTracksSelected {
            bulkSelection.selection.clear()
            return
        }

        let ids = trackSections.flatMap { section in
            section.tracks.map { $0.id }
        }

        bulkSelection.replaceSelection(with: ids)
    }

    /// Обрабатывает выбор массового действия из toolbar.
    func selectBulkAction(_ action: BulkTrackAction) {
        if bulkSelection.isActive {
            guard bulkSelection.hasSelection else {
                bulkSelection.setPendingAction(action)
                return
            }

            applyBulkAction(action)
            return
        }

        bulkSelection.activate(action: action)
    }

    /// Применяет действие, которое ожидает подтверждения через action bar.
    func applyPendingBulkAction() {
        guard let action = bulkSelection.pendingAction else { return }
        applyBulkAction(action)
    }

    /// Передаёт зафиксированный выбор в flow выбранного массового действия.
    private func applyBulkAction(_ action: BulkTrackAction) {
        guard bulkSelection.hasSelection else { return }

        let pendingAction = PendingBulkTrackAction(
            action: action,
            trackIDs: bulkSelection.selection.ids
        )

        guard !pendingAction.isEmpty else { return }

        switch action {
        case .renameFiles:
            startBatchFilenameRenameLoading(with: pendingAction)
            Task { @MainActor in
                await prepareBatchFilenameRename(with: pendingAction)
            }
        case .editTags:
            startBatchTagEditFlow(pendingAction: pendingAction)
        case .addToPlayer, .addToTrackList:
            break
        }

        bulkSelection.reset()
    }

    /// Запускает flow массового редактирования тегов.
    private func startBatchTagEditFlow(pendingAction: PendingBulkTrackAction) {
        let loadingFlow = BatchTagEditFlow(
            pendingAction: pendingAction,
            phase: .loadingMetadata,
            tracks: [],
            fields: [],
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
                action: .keep,
                newArtworkData: nil,
                summary: .none,
                previewSummary: BatchTagArtworkPreviewSummary(
                    selectedCount: pendingAction.trackIDs.count,
                    artworkCount: 0,
                    missingArtworkCount: pendingAction.trackIDs.count
                ),
                previewItems: [],
                selectedTarget: nil
            )
        )

        SheetManager.shared.presentBatchTagEdit(
            flow: loadingFlow,
            onSave: { [weak self] in
                await self?.applyBatchTagEdit()
            }
        )

        Task { [pendingAction] in
            let loadedFlow = await BatchTagMetadataLoader().loadFlow(
                pendingAction: pendingAction
            )
            guard SheetManager.shared.batchTagEditFlow.pendingAction?.trackIDs == pendingAction.trackIDs else { return }
            SheetManager.shared.batchTagEditFlow = loadedFlow
        }
    }

    /// Сохраняет массовые изменения тегов.
    private func applyBatchTagEdit() async {
        let flow = SheetManager.shared.batchTagEditFlow
        let pendingAction = flow.pendingAction
        let selectedTarget = flow.artwork.selectedTarget

        guard let pendingAction else {
            ToastManager.shared.handle(.batchTagsUpdateFailed(failed: flow.tracks.count))
            return
        }

        do {
            let plan = try BatchTagEditSavePlanner.makePlan(from: flow)
            let result = await BatchTagEditSaveExecutor().execute(plan: plan)

            if result.failedCount == 0 {
                ToastManager.shared.handle(.batchTagsUpdated(count: result.succeededCount))
            } else if result.succeededCount > 0 {
                ToastManager.shared.handle(
                    .batchTagsPartiallyUpdated(
                        succeeded: result.succeededCount,
                        failed: result.failedCount
                    )
                )
            } else {
                ToastManager.shared.handle(.batchTagsUpdateFailed(failed: result.failedCount))
            }

            if result.succeededCount > 0 {
                await reloadBatchTagEditFlowAfterSave(
                    pendingAction: pendingAction,
                    selectedTarget: selectedTarget
                )
            }
        } catch {
            ToastManager.shared.handle(.batchTagsUpdateFailed(failed: flow.tracks.count))
        }
    }

    /// Обновляет данные открытого sheet массового редактирования тегов после сохранения.
    private func reloadBatchTagEditFlowAfterSave(
        pendingAction: PendingBulkTrackAction,
        selectedTarget: BatchTagArtworkActionTarget?
    ) async {
        let reloadedFlow = await BatchTagMetadataLoader().loadFlow(
            pendingAction: pendingAction
        )

        guard SheetManager.shared.batchTagEditFlow.pendingAction?.trackIDs == pendingAction.trackIDs else { return }
        var updatedFlow = reloadedFlow
        updatedFlow.artwork.selectedTarget = selectedTarget ?? .summary
        updatedFlow.phase = .editing
        SheetManager.shared.batchTagEditFlow = updatedFlow
    }

    /// Применяет массовое переименование файлов для готовых строк плана.
    func applyBatchFilenameRename(using playerManager: PlayerManager) async {
        guard !batchFilenameRenameFlow.isBusy else { return }
        // До выбора стратегии targetFileName равен текущему имени, поэтому применять такой план нельзя.
        guard batchFilenameRenameFlow.strategy != nil else { return }

        let commands = batchFilenameRenameFlow.items
            .filter { $0.status == .ready }
            .map { item in
                BatchFilenameRenameCommand(
                    trackId: item.trackId,
                    currentFileName: item.currentFileName,
                    targetFileName: item.targetFileName
                )
            }

        guard !commands.isEmpty else { return }

        batchFilenameRenameFlow.startApplyingRename(totalCount: commands.count)
        defer {
            batchFilenameRenameFlow.finishApplyingRename()
        }

        let result = await AppCommandExecutor.shared.renameTrackFilesBatch(
            commands,
            using: playerManager,
            progress: { [weak self] processed, _ in
                self?.batchFilenameRenameFlow.updateApplyingRenameProgress(
                    processedCount: processed
                )
            }
        )

        batchFilenameRenameFlow.applyResult(result)
    }

    /// Сразу открывает sheet массового переименования,
    /// пока metadata выбранных файлов ещё загружается.
    private func startBatchFilenameRenameLoading(with pendingAction: PendingBulkTrackAction) {
        batchFilenameRenameFlow.startLoadingMetadata(
            with: pendingAction,
            tracks: filenameRenameTracks(for: pendingAction.trackIDs)
        )
        batchFilenameRenameFlow.startPreparingRename(
            totalCount: pendingAction.trackIDs.count
        )
    }

    /// Подготавливает flow массового переименования после загрузки runtime metadata.
    private func prepareBatchFilenameRename(with pendingAction: PendingBulkTrackAction) async {
        defer {
            batchFilenameRenameFlow.finishPreparingRename()
        }

        await ensureSnapshotsForBatchRename(trackIDs: pendingAction.trackIDs)

        guard batchFilenameRenameFlow.pendingAction?.action == .renameFiles else { return }

        let currentTrackIDs = batchFilenameRenameFlow.pendingAction?.trackIDs ?? []
        guard !currentTrackIDs.isEmpty else { return }

        batchFilenameRenameFlow.prepare(
            with: PendingBulkTrackAction(
                action: .renameFiles,
                trackIDs: currentTrackIDs
            ),
            tracks: filenameRenameTracks(for: currentTrackIDs)
        )
        batchFilenameRenameFlow.validateRequiredMetadata()
    }

    /// Загружает runtime snapshots для batch rename.
    /// Использует существующий runtime pipeline:
    /// TrackRuntimeStore -> TrackRuntimeSnapshotBuilder.
    private func ensureSnapshotsForBatchRename(trackIDs: [UUID]) async {
        let limiter = AsyncLimiter(limit: 6)
        var preparedCount = 0

        /// Фиксирует завершение подготовки одного трека.
        func updatePreparedCount() {
            preparedCount += 1
            batchFilenameRenameFlow.updatePreparingRenameProgress(
                preparedCount: preparedCount
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for trackID in trackIDs {
                if snapshotsByTrackId[trackID] != nil {
                    updatePreparedCount()
                    continue
                }

                group.addTask { [weak self] in
                    guard let self else { return }

                    await limiter.acquire()

                    if let storedSnapshot = await TrackRuntimeStore.shared.snapshot(forTrackId: trackID) {
                        await MainActor.run {
                            self.snapshotsByTrackId[trackID] = storedSnapshot
                        }
                        await limiter.release()
                        return
                    }

                    guard let snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackID) else {
                        await limiter.release()
                        return
                    }

                    await TrackRuntimeStore.shared.storeSnapshot(snapshot)

                    await MainActor.run {
                        self.snapshotsByTrackId[trackID] = snapshot
                    }

                    await limiter.release()
                }
            }

            for await _ in group {
                updatePreparedCount()
            }
        }
    }

    /// Собирает входные данные для плана переименования в порядке выбранных trackIDs.
    private func filenameRenameTracks(for trackIDs: [UUID]) -> [BatchFilenameRenameTrack] {
        let tracksById = Dictionary(
            uniqueKeysWithValues: trackSections
                .flatMap(\.tracks)
                .map { ($0.id, $0) }
        )

        return trackIDs.compactMap { trackId in
            guard let track = tracksById[trackId] else { return nil }

            let snapshot = snapshotsByTrackId[trackId]

            return BatchFilenameRenameTrack(
                trackId: trackId,
                folderPath: track.fileURL.deletingLastPathComponent().standardizedFileURL.path,
                currentFileName: track.fileURL.lastPathComponent,
                artist: snapshot?.artist ?? track.artist,
                title: snapshot?.title ?? track.title
            )
        }
    }
    
    /// Проверяет доступность треков после первичного отображения списка.
    private func updateAvailabilityInBackground() async {
        let tracks = trackSections.flatMap { $0.tracks }
        var availabilityById: [UUID: Bool] = [:]

        for track in tracks {
            availabilityById[track.id] = await BookmarkResolver.url(forTrack: track.id) != nil
        }

        trackSections = trackSections.map { section in
            let updatedTracks = section.tracks.map { track in
                let isAvailable = availabilityById[track.id] ?? track.isAvailable
                return LibraryTrack(
                    id: track.id,
                    fileURL: track.fileURL,
                    title: track.title,
                    artist: track.artist,
                    duration: track.duration,
                    addedDate: track.addedDate,
                    isAvailable: isAvailable
                )
            }

            return TrackSection(
                id: section.id,
                title: section.title,
                tracks: updatedTracks
            )
        }
    }
    

    // MARK: - TrackRuntimeProviding

    /// Возвращает runtime snapshot трека по его идентификатору.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: TrackRuntimeSnapshot или nil
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        if snapshotsByTrackId[trackId] != nil { return }

        Task {
            let snapshot: TrackRuntimeSnapshot?

            if let storedSnapshot = TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
                snapshot = storedSnapshot
            } else {
                snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
            }

            guard let snapshot else { return }

            await MainActor.run {
                snapshotsByTrackId[trackId] = snapshot
            }
        }
    }

    /// Пересобирает runtime snapshot загруженных треков после изменения настроек приложения.
    private func reloadSnapshotsAfterSettingsChange() {
        snapshotsByTrackId.removeAll()
        let trackIds = trackSections
            .flatMap { $0.tracks }
            .map { $0.id }
        for trackId in trackIds {
            requestSnapshotIfNeeded(for: trackId)
        }
    }

    /// Применяет единое событие обновления трека к состоянию фонотеки.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        applyTrackUpdateEvents([updateEvent])
    }

    /// Пакетно применяет события обновления треков к секциям без полного refresh списка.
    private func applyTrackUpdateEvents(_ events: [TrackUpdateEvent]) {
        guard !events.isEmpty else { return }

        let eventsByTrackId = events.reduce(into: [UUID: TrackUpdateEvent]()) { result, event in
            result[event.trackId] = event
        }

        var updatedSnapshots = snapshotsByTrackId
        for event in events {
            updatedSnapshots[event.trackId] = event.snapshot
        }
        snapshotsByTrackId = updatedSnapshots

        trackSections = trackSections.map { section in
            let updatedTracks = section.tracks.map { track in
                guard let updateEvent = eventsByTrackId[track.id] else { return track }
                return updatedLibraryTrack(from: track, using: updateEvent)
            }

            return TrackSection(
                id: section.id,
                title: section.title,
                tracks: updatedTracks
            )
        }
    }

    /// Собирает обновлённую модель строки фонотеки из runtime snapshot.
    private func updatedLibraryTrack(
        from track: LibraryTrack,
        using updateEvent: TrackUpdateEvent
    ) -> LibraryTrack {
        let snapshot = updateEvent.snapshot
        let fileURL = updatedFileURL(
            currentURL: track.fileURL,
            snapshot: snapshot,
            changedFields: updateEvent.changedFields
        )

        return LibraryTrack(
            id: track.id,
            fileURL: fileURL,
            title: updatedOptionalString(
                currentValue: track.title,
                snapshotValue: snapshot.title,
                field: .title,
                changedFields: updateEvent.changedFields
            ),
            artist: updatedOptionalString(
                currentValue: track.artist,
                snapshotValue: snapshot.artist,
                field: .artist,
                changedFields: updateEvent.changedFields
            ),
            duration: updateEvent.changedFields.contains(.duration)
                ? snapshot.duration ?? track.duration
                : track.duration,
            addedDate: track.addedDate,
            isAvailable: updateEvent.changedFields.contains(.isAvailable)
                ? snapshot.isAvailable
                : track.isAvailable
        )
    }

    /// Обновляет optional-строку только если соответствующее поле действительно менялось.
    private func updatedOptionalString(
        currentValue: String?,
        snapshotValue: String?,
        field: TrackChangedField,
        changedFields: Set<TrackChangedField>
    ) -> String? {
        changedFields.contains(field) ? snapshotValue : currentValue
    }

    /// Обновляет URL строки после rename, не перечитывая весь список фонотеки.
    private func updatedFileURL(
        currentURL: URL,
        snapshot: TrackRuntimeSnapshot,
        changedFields: Set<TrackChangedField>
    ) -> URL {
        guard changedFields.contains(.fileName) else { return currentURL }

        return currentURL
            .deletingLastPathComponent()
            .appendingPathComponent(snapshot.fileName)
    }
}
