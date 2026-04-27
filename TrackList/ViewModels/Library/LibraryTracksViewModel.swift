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

@MainActor
final class LibraryTracksViewModel: ObservableObject, TrackMetadataProviding {

    // MARK: - Входные данные

    let folderURL: URL
    let folderId: UUID

    // MARK: - Состояния

    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime snapshot треков по id
    @Published var isLoading = false
    @Published private(set) var didLoad = false
    
    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider

    // MARK: - Init

    init(
        folderURL: URL,
        tracksProvider: LibraryTracksProvider = DefaultLibraryTracksProvider(),
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

        await MusicLibraryManager.shared.syncFolderIfNeeded(folderId: folderId)

        let all = await TrackRegistry.shared.allTracks()
        print("📦 TrackRegistry total:", all.count)
        print("📂 UI folderId:", folderId)

        let tracks = await tracksProvider.tracks(inFolder: folderId)

        print("🎵 tracks in folder:", tracks.count)

        trackSections = TrackSectionBuilder.build(
            from: tracks,
            mode: .date
        )

        let ids = trackSections.flatMap { $0.tracks }.map { $0.id }
        trackListNamesById = badgeProvider.badges(for: ids)
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

    /// Применяет единое событие обновления трека к состоянию фонотеки.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
    }
}
