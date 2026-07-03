//
//  TrackListRowStateBuilder.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation
import UIKit

/// Собирает состояние строки трека в одном треклисте.
/// Builder изолирует вычисления отображения от SwiftUI View.
@MainActor
struct TrackListRowStateBuilder {

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
        isHighlighted: Bool
    ) -> TrackListRowState {
        build(
            track: track,
            snapshot: snapshot,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            settingsManager: .shared
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
    ///   - settingsManager: Менеджер настроек отображения.
    /// - Returns: Готовое состояние строки для UI.
    func build(
        track: Track,
        snapshot: TrackRuntimeSnapshot?,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        settingsManager: AppSettingsManager
    ) -> TrackListRowState {
        let shouldShowTags = settingsManager.settings.visible.metadata.isTagReadingEnabled
        let shouldShowFileFormat = settingsManager.settings.visible.library.isFileFormatVisible
        if track.isPurchasedITunesRuntimeTrack {
            return TrackListRowState(
                id: track.id,
                trackId: track.trackId,
                title: track.title ?? track.fileName,
                artist: track.artist ?? "",
                fileName: track.fileName,
                source: track.source,
                duration: track.duration,
                isAvailable: track.isAvailable,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                isHighlighted: isHighlighted,
                artwork: track.artwork,
                showsFileFormat: false,
                renameArtist: nil,
                renameTitle: nil
            )
        }

        let displayFileName = snapshot?.fileName ?? track.fileName
        let title = shouldShowTags ? (snapshot?.title ?? displayFileName) : displayFileName
        let artist = shouldShowTags ? (snapshot?.artist ?? "") : ""
        let artwork: UIImage?

        if shouldShowTags, let artworkData = snapshot?.artworkData {
            artwork = ArtworkProvider.shared.image(
                trackId: track.trackId,
                artworkData: artworkData,
                purpose: .trackList
            )
        } else {
            artwork = nil
        }

        return TrackListRowState(
            id: track.id,
            trackId: track.trackId,
            title: title,
            artist: artist,
            fileName: displayFileName,
            source: track.source,
            duration: snapshot?.duration ?? track.duration,
            isAvailable: snapshot?.isAvailable ?? track.isAvailable,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artwork: artwork,
            showsFileFormat: shouldShowFileFormat,
            renameArtist: snapshot?.artist,
            renameTitle: snapshot?.title
        )
    }
}
