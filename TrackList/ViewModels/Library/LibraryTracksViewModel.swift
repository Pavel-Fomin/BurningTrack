//
//  LibraryTracksViewModel.swift
//  TrackList
//
//  ViewModel для треков внутри папки
//  Отвечает за список, выбор и координацию runtime-снимков фонотеки
//
//  Created by Pavel Fomin on 12.12.2025.
//

import Foundation
import Combine

@MainActor
final class LibraryTracksViewModel: ObservableObject, TrackMetadataProviding {

    // MARK: - Входные данные

    private let folderId: UUID

    // MARK: - Состояние списка

    @Published private(set) var trackSections: [TrackSection] = []
    @Published private(set) var trackListNamesById: [UUID: [String]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var didLoad = false

    // MARK: - Состояние выбора

    @Published var bulkSelection = BulkSelectionState<UUID, BulkTrackAction>()

    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    /// Предоставляет события обновления треков фонотеки.
    private let eventProvider: LibraryTrackEventProvider
    /// Управляет runtime snapshot pipeline фонотеки.
    private let runtimeController: LibraryTrackRuntimeController
    /// Собирает UI-состояние выбора строк фонотеки.
    private let selectionStateBuilder = LibrarySelectionStateBuilder()
    /// Обрабатывает подготовку и применение массового переименования файлов.
    private lazy var batchRenameHandler = LibraryBatchRenameHandler(
        snapshotProvider: { [weak self] trackId in
            self?.runtimeController.snapshot(for: trackId)
        },
        snapshotLoader: { [weak self] trackId in
            await self?.runtimeController.loadSnapshotIfNeeded(for: trackId)
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
        badgeProvider: TrackListBadgeProvider = DefaultTrackListBadgeProvider(),
        eventProvider: LibraryTrackEventProvider = NotificationLibraryTrackEventProvider(),
        runtimeController: LibraryTrackRuntimeController = LibraryTrackRuntimeController()
    ) {
        self.folderId = folderURL.libraryFolderId

        self.renameActionHandler = renameActionHandler
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider
        self.eventProvider = eventProvider
        self.runtimeController = runtimeController

        bindRuntimeController()
        bindBatchRenameHandler()
        bindTrackUpdateEvents()
        bindSettingsEvents()
        bindBadgeEvents()
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

        let snapshot = runtimeController.snapshot(for: track.trackId)
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

    /// Пробрасывает изменения runtime controller наружу для подписчиков ViewModel.
    private func bindRuntimeController() {
        runtimeController.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Подписывается на события обновления треков через event provider.
    private func bindTrackUpdateEvents() {
        eventProvider.trackDidUpdate
            .sink { [weak self] updateEvent in
                Task { @MainActor in
                    self?.applyTrackUpdateEvent(updateEvent)
                }
            }
            .store(in: &cancellables)

        eventProvider.trackBatchDidUpdate
            .sink { [weak self] events in
                Task { @MainActor in
                    self?.applyTrackUpdateEvents(events)
                }
            }
            .store(in: &cancellables)
    }

    /// Подписывается на событие изменения настроек приложения через event provider.
    private func bindSettingsEvents() {
        eventProvider.appSettingsDidChange
            .sink { [weak self] in
                Task { @MainActor in
                    self?.reloadSnapshotsAfterSettingsChange()
                }
            }
            .store(in: &cancellables)
    }

    /// Подписывается на события изменения треклистов через event provider.
    private func bindBadgeEvents() {
        eventProvider.trackListBadgesDidChange
            .sink { [weak self] in
                Task { @MainActor in
                    self?.reloadTrackListBadges()
                }
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
        runtimeController.snapshot(for: trackId)
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        runtimeController.requestSnapshotIfNeeded(for: trackId)
    }

    /// Пересобирает runtime snapshot загруженных треков после изменения настроек приложения.
    private func reloadSnapshotsAfterSettingsChange() {
        runtimeController.clearSnapshots()
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

        runtimeController.applyTrackUpdateEvents(events)

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
