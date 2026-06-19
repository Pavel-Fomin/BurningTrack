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

struct TrackListRowView: View {
    
    // MARK: - Input
    
    let state: TrackListRowState /// Готовое состояние строки треклиста
    let onTap: () -> Void        /// Тап по строке (воспроизведение / пауза)
    let onDelete: () -> Void     /// Удаление строки (локальное действие)
    let onArtworkTap: () -> Void /// Тап по обложке
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: Track(
                listItemId: state.id,
                trackId: state.trackId,
                title: state.title,
                artist: state.artist,
                duration: state.duration,
                fileName: state.fileName,
                isAvailable: state.isAvailable
            ),
            isCurrent: state.isCurrent,
            isPlaying: state.isPlaying,
            isHighlighted: state.isHighlighted, /// Подсветка управляется wrapper'ом
            artwork: state.artwork,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: onTap,                    /// Правая зона — воспроизведение / пауза
            onArtworkTap: onArtworkTap,         /// Левая зона — делегируется выше (wrapper решает, что делать)
            showsFileFormat: state.showsFileFormat
        )
        
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
