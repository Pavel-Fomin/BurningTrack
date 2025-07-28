//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import Foundation

struct TrackRowView: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    
    let onTap: () -> Void
    var swipeActionsLeft: [CustomSwipeAction] = []
    var swipeActionsRight: [CustomSwipeAction] = []
    var trackListNames: [String]? = nil

    var body: some View {
        HStack(spacing: 12) {
            artworkView
            trackInfoView
            
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 4)
        .opacity(track.isAvailable ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            if track.isAvailable {
                onTap()
            } else {
                print("❌ Трек недоступен: \(track.title ?? track.fileName)")
            }
        }
        .customSwipeActions(
            swipeActionsLeft: swipeActionsLeft,
            swipeActionsRight: swipeActionsRight
        )
        
        .listRowBackground(
            isCurrent ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }

// MARK: - Обложка
    
    private var artworkView: some View {
        ZStack {
            if let image = track.artwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(48)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            }

            if isCurrent {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16, weight: .semibold))
                    .shadow(radius: 1)
            }
        }
    }

// MARK: - Информациия о треке
    
    private var trackInfoView: some View {
        let hasArtist: Bool = {
            guard let artist = track.artist?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
            return !artist.isEmpty && artist != "неизвестен"
        }()

        return VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
            if hasArtist, let artistText = track.artist {
                Text(artistText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            HStack {
                Text(track.title ?? track.fileName)
                    .font(hasArtist ? .footnote : .subheadline)
                    .foregroundColor(hasArtist ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Text(formatTimeSmart(track.duration))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
            }
            
            if let trackListNames, !trackListNames.isEmpty {
                Text("В треклисте: \(trackListNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
          }
        }
    }

