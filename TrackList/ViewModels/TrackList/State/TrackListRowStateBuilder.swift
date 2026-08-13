//
//  TrackListRowStateBuilder.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Собирает состояние строки трека в одном треклисте.
/// Builder изолирует вычисления отображения от SwiftUI View.
@MainActor
struct TrackListRowStateBuilder {

    /// Фабрика централизует сопоставление типизированного источника с бейджем.
    private let artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding

    /// Создаёт builder с общей фабрикой состояния бейджа.
    init(
        artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding = TrackArtworkBadgeStateFactory()
    ) {
        self.artworkBadgeStateFactory = artworkBadgeStateFactory
    }

    /// Собирает состояние строки трека.
    ///
    /// - Parameters:
    ///   - track: Трек из треклиста.
    ///   - snapshot: Runtime snapshot трека, если он уже загружен.
    ///   - isCurrent: Является ли строка текущим треком.
    ///   - isPlaying: Воспроизводится ли текущая строка.
    ///   - isHighlighted: Нужно ли подсветить строку.
    /// - Returns: Готовое состояние строки для UI.
    func build(
        track: Track,
        snapshot: TrackRuntimeSnapshot?,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        isFavorite: Bool
    ) -> TrackListRowState {
        build(
            track: track,
            snapshot: snapshot,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            isFavorite: isFavorite,
            settings: AppSettingsManager.shared.settings,
            collectionNavigationTarget: nil
        )
    }

    /// Собирает состояние строки трека с явным менеджером настроек.
    ///
    /// - Parameters:
    ///   - track: Трек из треклиста.
    ///   - snapshot: Runtime snapshot трека, если он уже загружен.
    ///   - isCurrent: Является ли строка текущим треком.
    ///   - isPlaying: Воспроизводится ли текущая строка.
    ///   - isHighlighted: Нужно ли подсветить строку.
    ///   - settings: Снимок настроек отображения на момент сборки состояния.
    /// - Returns: Готовое состояние строки для UI.
    func build(
        track: Track,
        snapshot: TrackRuntimeSnapshot?,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        isFavorite: Bool,
        settings: AppSettings,
        collectionNavigationTarget: TrackCollectionNavigationTarget?
    ) -> TrackListRowState {
        let shouldShowTags = settings.visible.metadata.isTagReadingEnabled
        let shouldShowFileFormat = settings.visible.library.isFileFormatVisible
        let availableActions = availableActions(
            for: track,
            collectionNavigationTarget: collectionNavigationTarget
        )

        if track.isPurchasedITunesRuntimeTrack {
            return TrackListRowState(
                id: track.id,
                trackId: track.trackId,
                title: track.title ?? track.fileName,
                artist: track.artist ?? "",
                fileName: track.fileName,
                source: track.source,
                availableActions: availableActions,
                duration: track.duration,
                isAvailable: track.isAvailable,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                isHighlighted: isHighlighted,
                isFavorite: isFavorite,
                artworkRequest: ArtworkRequest(
                    trackId: track.trackId,
                    artworkData: track.artworkData,
                    purpose: .trackList,
                    sourceIdentifier: .mediaLibrary(trackId: track.trackId)
                ),
                artworkBadgeState: artworkBadgeStateFactory.makeState(
                    source: track.source,
                    isFavorite: isFavorite
                ),
                collectionNavigationTarget: nil,
                showsFileFormat: false,
                renameArtist: nil,
                renameTitle: nil
            )
        }

        let displayFileName = snapshot?.fileName ?? track.fileName
        let title = shouldShowTags ? (snapshot?.title ?? displayFileName) : displayFileName
        let artist = shouldShowTags ? (snapshot?.artist ?? "") : ""
        let artworkRequest: ArtworkRequest?

        if shouldShowTags {
            artworkRequest = ArtworkRequest(
                trackId: track.trackId,
                snapshot: snapshot,
                purpose: .trackList
            )
        } else {
            artworkRequest = nil
        }

        return TrackListRowState(
            id: track.id,
            trackId: track.trackId,
            title: title,
            artist: artist,
            fileName: displayFileName,
            source: track.source,
            availableActions: availableActions,
            duration: snapshot?.duration ?? track.duration,
            isAvailable: snapshot?.isAvailable ?? track.isAvailable,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            isFavorite: isFavorite,
            artworkRequest: artworkRequest,
            artworkBadgeState: artworkBadgeStateFactory.makeState(
                source: track.source,
                isFavorite: isFavorite
            ),
            collectionNavigationTarget: collectionNavigationTarget,
            showsFileFormat: shouldShowFileFormat,
            renameArtist: snapshot?.artist,
            renameTitle: snapshot?.title
        )
    }

    /// Учитывает источник, контекст треклиста и факт подготовки цели навигации до передачи state во View.
    private func availableActions(
        for track: Track,
        collectionNavigationTarget: TrackCollectionNavigationTarget?
    ) -> Set<TrackMenuAction> {
        var actions = TrackMenuActionAvailability.availableActions(
            source: track.source,
            context: .trackList
        )

        if collectionNavigationTarget?.artist == nil {
            actions.remove(.goToArtist)
        }
        if collectionNavigationTarget?.album == nil {
            actions.remove(.goToAlbum)
        }

        return actions
    }
}
