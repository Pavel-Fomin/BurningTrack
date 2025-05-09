//
//  TrackListView.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI
import AVFoundation

struct TrackListView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            ForEach(trackListViewModel.tracks) { track in
                trackRow(for: track)
            }
            .onDelete { indexSet in
                trackListViewModel.removeTrack(at: indexSet)
            }
            .onMove { indices, newOffset in
                trackListViewModel.moveTrack(from: indices, to: newOffset)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        
       
    }

    private func trackRow(for track: Track) -> some View {
        HStack(spacing: 12) {
            // Обложка слева
            if let image = track.artwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.artist ?? "Неизвестный артист")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack {
                    Text(track.title)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTimeSmart(track.duration))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

           
        }
        .padding(.vertical, 4)
        .listRowBackground(
            playerViewModel.currentTrack?.id == track.id
            ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
            : Color.clear
        )
        .onTapGesture {
            if playerViewModel.currentTrack?.id == track.id {
                playerViewModel.togglePlayPause()
            } else {
                print("🎯 Tap по треку:", track.title)

                if playerViewModel.currentTrack?.id == track.id {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track)
                }
            }
        }
    }
}
struct TrackListView_Previews: PreviewProvider {
    static var previews: some View {
        TrackListView(
            trackListViewModel: TrackListViewModel(),
            playerViewModel: PlayerViewModel()
        )
        .environment(\.editMode, .constant(.active))
    }
}
