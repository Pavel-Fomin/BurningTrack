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
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void     /// Тап по строке (воспроизведение / пауза)
    let onDelete: () -> Void  /// Удаление строки (локальное действие)
    let metadataProvider: TrackMetadataProviding
    
    
    // MARK: - Metadata
    
    /// Обложка
    private var artwork: UIImage? {
        guard let meta = metadataProvider.metadata(for: track.id),
              let data = meta.artworkData
        else { return nil }

        return ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: data,
            purpose: .trackList
        )
    }
    
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: false,                   /// Подсветка управляется wrapper'ом
            artwork: artwork,
            title: track.title ?? track.fileName,
            artist: track.artist ?? "",
            duration: track.duration,
            onRowTap: onTap,                       /// Правая зона — воспроизведение / пауза
            onArtworkTap: {}                       /// Левая зона — делегируется выше (wrapper решает, что делать)
        )
        
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
