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

    // MARK: - Observer

    private var trackDidMoveObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        folderId: UUID,
        tracksProvider: LibraryTracksProvider = DefaultLibraryTracksProvider(),
        badgeProvider: TrackListBadgeProvider = DefaultTrackListBadgeProvider()
    ) {
        self.folderId = folderId
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider

        trackDidMoveObserver = NotificationCenter.default.addObserver(
            forName: .trackDidMove,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }

            Task { @MainActor in
                self.handleTrackDidMove(notification)
            }
        }
    }

    deinit {
        if let observer = trackDidMoveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Load

    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    // MARK: - Refresh

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

    // MARK: - Track move handling

    private func handleTrackDidMove(_ notification: Notification) {
        guard let trackId = notification.object as? UUID else { return }

        Task { @MainActor in
            guard let entry = await TrackRegistry.shared.entry(for: trackId) else { return }

            if entry.folderId != folderId {
                removeTrackFromSections(trackId: trackId)
            }
        }
    }

    private func removeTrackFromSections(trackId: UUID) {
        trackSections = trackSections
            .map { section in
                let filtered = section.tracks.filter { $0.id != trackId }
                return TrackSection(
                    id: section.id,
                    title: section.title,
                    tracks: filtered
                )
            }
            .filter { !$0.tracks.isEmpty }

        metadataByTrackId.removeValue(forKey: trackId)
        trackListNamesById.removeValue(forKey: trackId)
    }
}
