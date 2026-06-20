//
//  LibraryTracksViewModel.swift
//  TrackList
//
//  ViewModel для треков внутри папки
//  Отвечает за список, выбор и runtime-снимки фонотеки
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

    // MARK: - Состояние списка

    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published var isLoading = false
    @Published private(set) var didLoad = false

    // MARK: - Состояние выбора

    @Published var bulkSelection = BulkSelectionState<UUID, BulkTrackAction>()

    // MARK: - Состояние runtime-снимков

    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime-снимки треков по id
    
    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    /// Собирает UI-состояние выбора строк фонотеки.
    private let selectionStateBuilder = LibrarySelectionStateBuilder()
    /// Обрабатывает подготовку и применение массового переименования файлов.
    private lazy var batchRenameHandler = LibraryBatchRenameHandler(
        snapshotProvider: { [weak self] trackId in
            self?.snapshotsByTrackId[trackId]
        },
        snapshotStore: { [weak self] trackId, snapshot in
            self?.snapshotsByTrackId[trackId] = snapshot
        },
        tracksProvider: { [weak self] in
            self?.trackSections.flatMap(\.tracks) ?? []
        }
    )
    /// Обрабатывает массовое редактирование тегов.
    private let batchTagEditHandler = LibraryBatchTagEditHandler()
    /// Маршрутизирует зафиксированные массовые действия в текущие массовые сценарии.
    private lazy var batchActionHandler = LibraryBatchActionHandler(
        onRenameFiles: { [weak self] pendingAction in
            self?.batchRenameHandler.startRename(with: pendingAction)
        },
        onEditTags: { [weak self] pendingAction in
            self?.batchTagEditHandler.startEdit(with: pendingAction)
        }
    )

    /// Общий обработчик переименования файлов треков.
    private let renameActionHandler: TrackFileRenameActionHandler

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Производное состояние

    /// Состояние массового переименования файлов для существующего модального окна.
    var batchFilenameRenameFlow: BatchFilenameRenameFlow {
        batchRenameHandler.flow
    }

    /// Общее количество видимых строк в текущих секциях.
    var totalVisibleTrackCount: Int {
        selectionStateBuilder.visibleRowIds(from: trackSections).count
    }

    /// Показывает, выбраны ли все видимые строки.
    var areAllVisibleTracksSelected: Bool {
        selectionStateBuilder.areAllVisibleRowsSelected(
            sections: trackSections,
            selection: bulkSelection.selection
        )
    }

    // MARK: - Инициализация

    init(
        folderURL: URL,
        renameActionHandler: TrackFileRenameActionHandler,
        tracksProvider: LibraryTracksProvider = FastLibraryTracksProvider(),
        badgeProvider: TrackListBadgeProvider = DefaultTrackListBadgeProvider()
    ) {
        self.folderURL = folderURL
        self.folderId = folderURL.libraryFolderId

        self.renameActionHandler = renameActionHandler
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider

        bindBatchRenameHandler()

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

    // MARK: - Переименование

    /// Запускает сценарий переименования файла трека из фонотеки.
    func renameTrack(
        trackId: UUID,
        strategy: FileRenameStrategy
    ) {
        guard let track = trackSections
            .flatMap(\.tracks)
            .first(where: { $0.trackId == trackId })
        else {
            return
        }

        let snapshot = snapshotsByTrackId[track.trackId]
        let request = TrackFileRenameRequest(
            trackId: track.trackId,
            rowId: track.id,
            currentFileName: snapshot?.fileName ?? track.fileName,
            artist: snapshot?.artist,
            title: snapshot?.title,
            strategy: strategy
        )
        renameActionHandler.handle(request)
    }
    
    // MARK: - Загрузка

    func loadTracksIfNeeded() async {
        // Если уже загружали — ничего не делаем
        if didLoad {return}
        didLoad = true

        await refresh()
    }

    // MARK: - Обновление

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

    /// Проверяет доступность треков после первичного отображения списка.
    private func updateAvailabilityInBackground() async {
        let tracks = trackSections.flatMap { $0.tracks }
        var availabilityByRowId: [UUID: Bool] = [:]

        for track in tracks {
            availabilityByRowId[track.id] = await BookmarkResolver.url(forTrack: track.trackId) != nil
        }

        trackSections = trackSections.map { section in
            let updatedTracks = section.tracks.map { track in
                let isAvailable = availabilityByRowId[track.id] ?? track.isAvailable
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

    // MARK: - Бейджи

    /// Обновляет бейджи треклистов для уже загруженных треков.
    /// Не перезагружает сами треки и не меняет секции.
    private func reloadTrackListBadges() {
        let ids = trackSections.flatMap { $0.tracks }.map { $0.trackId }
        trackListNamesById = badgeProvider.badges(for: ids)
    }

    // MARK: - Выбор

    /// Включает режим массового выбора без заранее выбранного действия.
    func activateBulkSelection() {
        bulkSelection.activate()
    }

    /// Сбрасывает режим массового выбора и текущий selection.
    func resetBulkSelection() {
        bulkSelection.reset()
    }

    /// Выбирает все видимые строки или снимает выбор со всех, если уже выбраны все.
    func toggleSelectAllVisibleTracks() {
        guard bulkSelection.isActive else { return }

        if areAllVisibleTracksSelected {
            bulkSelection.selection.clear()
            return
        }

        let ids = selectionStateBuilder.visibleRowIds(from: trackSections)

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

    // MARK: - Массовые действия

    /// Передаёт зафиксированный выбор в flow выбранного массового действия.
    private func applyBulkAction(_ action: BulkTrackAction) {
        guard bulkSelection.hasSelection else { return }

        let selectedTrackIds = selectionStateBuilder.selectedTrackIds(
            selection: bulkSelection.selection,
            sections: trackSections
        )

        let pendingAction = PendingBulkTrackAction(
            action: action,
            trackIDs: selectedTrackIds
        )

        batchActionHandler.handle(pendingAction)
        bulkSelection.reset()
    }

    /// Пробрасывает изменения handler массового переименования наружу для подписчиков ViewModel.
    private func bindBatchRenameHandler() {
        batchRenameHandler.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Применяет массовое переименование файлов через batch rename handler.
    func applyBatchFilenameRename(using playerManager: PlayerManager) async {
        await batchRenameHandler.applyRename(using: playerManager)
    }

    // MARK: - Runtime-снимки

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
            .map { $0.trackId }
        for trackId in trackIds {
            requestSnapshotIfNeeded(for: trackId)
        }
    }

    // MARK: - Обновления треков

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
                guard let updateEvent = eventsByTrackId[track.trackId] else { return track }
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
