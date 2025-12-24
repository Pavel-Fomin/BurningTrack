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

    let folderId: UUID

    // MARK: - Состояния

    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published private(set) var metadataByTrackId: [UUID: TrackMetadataCacheManager.CachedMetadata] = [:]
    @Published var isLoading = false
    @Published private(set) var didLoad = false

    // MARK: - Зависимости

    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider

    // MARK: - Init

    init(
        folderId: UUID,
        tracksProvider: LibraryTracksProvider = DefaultLibraryTracksProvider(),
        badgeProvider: TrackListBadgeProvider = DefaultTrackListBadgeProvider()
    ) {
        self.folderId = folderId
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider
    }

    // MARK: - Load

    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    // MARK: - Refresh

    /// Явное обновление данных.
    /// Вызывается строго из UX-слоя.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let tracks = await tracksProvider.tracks(inFolder: folderId)

        trackSections = TrackSectionBuilder.build(
            from: tracks,
            mode: .date
        )

        let ids = trackSections.flatMap { $0.tracks }.map { $0.id }
        trackListNamesById = badgeProvider.badges(for: ids)
    }

    // MARK: - TrackMetadataProviding

    func metadata(for trackId: UUID)
    -> TrackMetadataCacheManager.CachedMetadata? {
        metadataByTrackId[trackId]
    }

    func requestMetadataIfNeeded(for trackId: UUID) {
        if metadataByTrackId[trackId] != nil { return }

        Task {
            guard
                let url = await BookmarkResolver.url(forTrack: trackId),
                let meta = await TrackMetadataCacheManager.shared.loadMetadata(for: url)
            else { return }

            await MainActor.run {
                metadataByTrackId[trackId] = meta
            }
        }
    }
}
