//
//  TrackSelectableRowWrapper.swift
//  TrackList
//
//  Обёртка для использования TrackRowView в режиме выбора треков.
//  Не содержит логики плеера и сторонних зависимостей.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

struct TrackSelectableRowWrapper: View {
    
    // MARK: - Input
    
    let track: LibraryTrack
    let isSelected: Bool
    let metadataProvider: TrackMetadataProviding
    let onToggleSelection: () -> Void

    @ObservedObject private var settingsManager = AppSettingsManager.shared
    
    // MARK: - Snapshot
    
    /// Runtime snapshot трека (единый источник метаданных)
    private var snapshot: TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: track.trackId)
    }
    
    /// Лёгкий запрос обложки строится из snapshot без запуска подготовки во View.
    private var artworkRequest: ArtworkRequest? {
        return ArtworkRequest(
            trackId: track.trackId,
            snapshot: snapshot,
            purpose: .trackList
        )
    }
    
    // MARK: - UI
    
    var body: some View {
        let shouldShowFileFormat = settingsManager.settings.visible.library.isFileFormatVisible

        TrackRowView(
            track: track,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            artworkRequest: artworkRequest,
            title: snapshot?.title ?? track.title,
            artist: snapshot?.artist ?? track.artist ?? "",
            duration: snapshot?.duration ?? track.duration,
            onRowTap: {
                onToggleSelection()
            },
            showsSelection: true,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            selectionPlacement: .trailing,
            showsFileFormat: shouldShowFileFormat
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
        .task(id: track.trackId) {
            metadataProvider.requestSnapshotIfNeeded(for: track.trackId)
        }
    }
}
