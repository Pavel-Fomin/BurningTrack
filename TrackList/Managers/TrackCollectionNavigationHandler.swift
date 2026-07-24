//
//  TrackCollectionNavigationHandler.swift
//  TrackList
//
//  Обрабатывает переходы из контекстного меню трека к значениям музыкальной коллекции.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Получает сохранённые metadata трека и открывает соответствующее значение музыкальной коллекции.
@MainActor
final class TrackCollectionNavigationHandler {
    /// Общий обработчик межэкранных переходов к музыкальной коллекции.
    static let shared = TrackCollectionNavigationHandler(
        trackRegistry: .shared,
        navigationCoordinator: .shared
    )

    private let trackRegistry: TrackRegistry
    private let navigationCoordinator: NavigationCoordinator

    init(
        trackRegistry: TrackRegistry,
        navigationCoordinator: NavigationCoordinator
    ) {
        self.trackRegistry = trackRegistry
        self.navigationCoordinator = navigationCoordinator
    }

    /// Открывает артиста трека по сохранённым SQLite metadata.
    func openArtist(trackId: UUID) {
        openCollectionValue(
            trackId: trackId,
            category: .artists
        )
    }

    /// Открывает альбом трека по сохранённым SQLite metadata.
    func openAlbum(trackId: UUID) {
        openCollectionValue(
            trackId: trackId,
            category: .albums
        )
    }

    /// Запрашивает metadata без чтения файла и передаёт значение в существующую навигацию фонотеки.
    private func openCollectionValue(
        trackId: UUID,
        category: LibraryCollectionCategory
    ) {
        Task { [trackRegistry, navigationCoordinator] in
            guard let metadata = await trackRegistry
                .cachedMetadata(forTrackIds: [trackId])[trackId] else {
                return
            }

            let target = TrackCollectionNavigationTarget(metadata: metadata)

            switch category {
            case .artists:
                guard let artist = target.artist else { return }
                navigationCoordinator.openCollectionValueFromApp(
                    category: .artists,
                    value: artist
                )

            case .albums:
                guard let album = target.album else { return }
                navigationCoordinator.openCollectionValueFromApp(
                    category: .albums,
                    value: album,
                    artistKey: target.albumArtistKey
                )

            case .genres, .labels, .years:
                return
            }
        }
    }
}
