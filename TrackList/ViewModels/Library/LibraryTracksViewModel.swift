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
    @Published var isLoading = false
    @Published private(set) var didLoad = false
    
    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    private var cancellables = Set<AnyCancellable>()

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
