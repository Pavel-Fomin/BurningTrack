//
//  TrackListRowView.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import Foundation

/// Строка трека в треклисте.
/// ЧИСТЫЙ UI-КОМПОНЕНТ:
/// - не содержит свайпов
/// - не знает про SheetManager
/// - не содержит навигации
/// - все действия передаются через колбэки
struct TrackListRowView: View {

    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void     /// Тап по строке (воспроизведение / пауза)
    let onDelete: () -> Void  /// Удаление строки (локальное действие)

    @State private var artwork: CGImage? = nil

    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: false,                  /// Подсветка управляется wrapper'ом
            artwork: artwork,
            title: track.title ?? track.fileName,
            artist: track.artist ?? "",
            duration: track.duration,
            onRowTap: onTap,                       /// Правая зона — воспроизведение / пауза
            onArtworkTap: {}                       /// Левая зона — делегируется выше (wrapper решает, что делать)
        )
        .task(id: track.id) {
            artwork = await ArtworkLoader.loadIfNeeded(
                current: artwork,
                trackId: track.id
            )
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
