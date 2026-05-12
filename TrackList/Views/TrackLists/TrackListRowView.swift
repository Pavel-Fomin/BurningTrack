//
//  TrackListRowView.swift
//  TrackList
//
//  Строка трека в треклисте.
//   UI-КОМПОНЕНТ:
// - не содержит свайпов
// - не знает про SheetManager
// - не содержит навигации
// - все действия передаются через колбэки
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import UIKit

struct TrackListRowView: View {
    
    // MARK: - Input
    
    let track: Track                             /// Трек строки
    let isCurrent: Bool                          /// Является ли строка текущим треком
    let isPlaying: Bool                          /// Воспроизводится ли текущий трек
    let isHighlighted: Bool                      /// Подсвечена ли строка
    let onTap: () -> Void                        /// Тап по строке (воспроизведение / пауза)
    let onDelete: () -> Void                     /// Удаление строки (локальное действие)
    let onArtworkTap: () -> Void                 /// Тап по обложке
    let metadataProvider: TrackMetadataProviding /// Провайдер runtime snapshot
    
    @ObservedObject private var settingsManager = AppSettingsManager.shared
    
    // MARK: - Snapshot
    
    // Runtime snapshot трека
    private var snapshot: TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: track.trackId)
    }
    
    // Обложка
    private var artwork: UIImage? {
        guard settingsManager.settings.visible.metadata.isTagReadingEnabled else { return nil }
        guard let data = snapshot?.artworkData else { return nil }

        return ArtworkProvider.shared.image(
            trackId: track.trackId,
            artworkData: data,
            purpose: .trackList
        )
    }
    
    
    // MARK: - UI
    
    var body: some View {
        let shouldShowTags = settingsManager.settings.visible.metadata.isTagReadingEnabled

        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,                            /// Подсветка управляется wrapper'ом
            artwork: artwork,
            title: shouldShowTags ? (snapshot?.title ?? track.fileName) : track.fileName,
            artist: shouldShowTags ? (snapshot?.artist ?? "") : "",
            duration: snapshot?.duration ?? track.duration,
            onRowTap: onTap,                                       /// Правая зона — воспроизведение / пауза
            onArtworkTap: onArtworkTap                             /// Левая зона — делегируется выше (wrapper решает, что делать)
        )
        
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
