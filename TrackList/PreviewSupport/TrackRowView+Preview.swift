//
//  TrackRowView+Preview.swift
//  TrackList
//
//  Изолированные Xcode Preview для строки трека.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI
import UIKit

/// Создаёт изолированную строку для Xcode Preview из рабочей модели `Track`.
private func makeTrackRowPreview(
    track: Track,
    isCurrent: Bool = false,
    isPlaying: Bool = false,
    artwork: UIImage? = nil
) -> some View {
    List {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: false,
            artwork: artwork,
            title: track.title,
            artist: track.artist,
            duration: track.duration,
            onRowTap: {},
            onArtworkTap: {}
        )
    }
    .listStyle(.plain)
}

#Preview("Обычное состояние") {
    let track = PreviewDataFactory.makeTracks()[0]

    makeTrackRowPreview(
        track: track,
        artwork: UIImage(systemName: "music.note")
    )
}

#Preview("Без обложки и метаданных") {
    makeTrackRowPreview(
        track: PreviewDataFactory.makeTrackWithoutArtwork()
    )
}

#Preview("Длинный текст") {
    makeTrackRowPreview(
        track: PreviewDataFactory.makeLongTextTrack(),
        artwork: UIImage(systemName: "music.note.list")
    )
}

#Preview("Текущий трек играет") {
    let track = PreviewDataFactory.makeTracks()[1]

    makeTrackRowPreview(
        track: track,
        isCurrent: true,
        isPlaying: true
    )
}

#Preview("Текущий трек на паузе") {
    let track = PreviewDataFactory.makeTracks()[2]

    makeTrackRowPreview(
        track: track,
        isCurrent: true,
        isPlaying: false
    )
}
#endif
