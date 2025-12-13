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
final class LibraryTracksViewModel: ObservableObject {
    
    // MARK: - Входные данные
    
    let folderId: UUID
    
    // MARK: - Состояния
    
    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]
    @Published var isLoading: Bool = false
    
    @Published private(set) var didLoad: Bool = false
    
    // MARK: - Subscriptions
    
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
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        let tracks = await tracksProvider.tracks(inFolder: folderId)
        
        self.trackSections = TrackSectionBuilder.build(
            from: tracks,
            mode: .date
        )
        
        // бейджи считаем здесь же, напрямую
        let idsInView = trackSections
            .flatMap { $0.tracks }
            .map { $0.id }
        
        trackListNamesById = badgeProvider.badges(for: idsInView)
    }
    
    // MARK: - TrackList Badges
    
    /// Бейджи треклистов рассчитываются при входе в папку (refresh).
    /// Realtime-обновление будет подключено через индекс trackId → trackListId.
    func loadTrackListNamesByURL() {
        
        let idsInView = trackSections
            .flatMap { $0.tracks }
            .map { $0.id }
        
        trackListNamesById = badgeProvider.badges(for: idsInView)
    }
    
    // MARK: - Metadata
    
    func setMetadata(
        _ meta: TrackMetadataCacheManager.CachedMetadata,
        for url: URL
    ) {
        metadataByURL[url] = meta
    }
}
