//
//  TrackRowView.swift
//  TrackList

//  UI-компонент для одного трека
//
//  Created by Pavel Fomin on 28.04.2025.
//
import SwiftUI
import Foundation

struct TrackRowView: View {
    let track: Track
    let isPlaying: Bool
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(track.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(formatTimeSmart(track.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isCurrent
            ? (Color.accentColor.opacity(0.12))
            : Color.clear
        )
        .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
    }
}
struct TrackRowView_Previews: PreviewProvider {
    static var previews: some View {
        TrackRowView(
            track: Track(
                id: UUID(),
                url: URL(string: "https://example.com")!,
                artist: "Test Artist",
                title: "Test Track",
                duration: 180,
                fileName: "test.mp3",
                artwork: nil
            ),
            isPlaying: true,
            isCurrent: true,
            onTap: {}
        )
    }
}
