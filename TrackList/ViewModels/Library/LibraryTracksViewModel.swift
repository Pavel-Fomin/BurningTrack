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

    /// Можно ли применить текущий план массового переименования.
    var canApplyBatchFilenameRename: Bool {
        guard batchFilenameRenameFlow.strategy != nil else { return false }

        return batchFilenameRenameFlow.items.contains { item in
            item.status == .ready
        }
    }

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
            batchFilenameRenameFlow.prepare(
                with: pendingAction,
                tracks: filenameRenameTracks(for: pendingAction.trackIDs)
            )
            batchFilenameRenameFlow.validateRequiredMetadata()
        case .addToPlayer, .addToTrackList, .editTags:
            break
        }

        bulkSelection.reset()
    }

    /// Выбирает стратегию и применяет её к текущему rename flow.
    func selectFilenameRenameStrategy(_ strategy: FilenameRenameStrategy) {
        batchFilenameRenameFlow.buildPlan(
            strategy: strategy,
            tracks: batchFilenameRenameFlow.tracks
        )
    }

    /// Исключает трек только из операции переименования и пересобирает план.
    func removeTrackFromRenameFlow(_ trackId: UUID) {
        batchFilenameRenameFlow.removeTrack(id: trackId)
    }

    /// Пересобирает план для оставшихся треков и заново рассчитывает целевые имена.
    func rebuildRenamePlan() {
        guard let strategy = batchFilenameRenameFlow.strategy else { return }

        batchFilenameRenameFlow.buildPlan(
            strategy: strategy,
            tracks: batchFilenameRenameFlow.tracks
        )
    }

    /// Закрывает flow массового переименования без изменений файлов.
    func resetBatchFilenameRenameFlow() {
        batchFilenameRenameFlow.reset()
    }

    /// Применяет массовое переименование файлов для готовых строк плана.
    func applyBatchFilenameRename(using playerManager: PlayerManager) async {
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

        let result = await AppCommandExecutor.shared.renameTrackFilesBatch(
            commands,
            using: playerManager
        )

        batchFilenameRenameFlow.applyResult(result)
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
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
    }
}
