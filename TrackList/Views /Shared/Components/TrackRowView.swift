//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UIKit
import Foundation

struct TrackRowView: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let isHighlighted: Bool
    let artwork: CGImage?
    let title: String?
    let artist: String?
    let onTap: () -> Void
    
    var swipeActionsLeft: [CustomSwipeAction] = []
    var swipeActionsRight: [CustomSwipeAction] = []
    var trackListNames: [String]? = nil
    var useNativeSwipeActions: Bool = false
    
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
        .listRowBackground(rowHighlightColor)
        
        .if(!useNativeSwipeActions) { view in
            view.customSwipeActions(
                swipeActionsLeft: swipeActionsLeft,
                swipeActionsRight: swipeActionsRight
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if useNativeSwipeActions {
                ForEach(swipeActionsRight) { action in
                    Button(role: action.role) {
                        action.handler()
                    } label: {
                        switch action.labelType {
                        case .iconOnly:
                            Image(systemName: action.systemImage)
                        case .textOnly:
                            Text(action.label)
                        case .iconAndText:
                            Label(action.label, systemImage: action.systemImage)
                        }
                    }
                    
                }
            }
        }
    }
    
    
    // MARK: - Обложка
    
    private var artworkView: some View {
        ZStack {
            if let artwork {
                RotatingArtworkView(
                    image: UIImage(cgImage: artwork),
                    isActive: isCurrent,
                    isPlaying: isPlaying,
                    size: 48,
                    rpm: 10
                )
                .frame(width: 48, height: 48)
                
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                if isCurrent {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                        .shadow(radius: 1)
                }
            }
        }
    }
    
    
    // MARK: - Информациия о треке
    
    private var trackInfoView: some View {
        let hasArtist: Bool = {
            guard let artist = artist?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
            return !artist.isEmpty && artist != "неизвестен"
        }()
        
        return VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
            if hasArtist, let artistText = artist {
                Text(artistText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            HStack {
                Text(title ?? track.fileName)
                    .font(hasArtist ? .footnote : .subheadline)
                    .foregroundColor(hasArtist ? .secondary : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatTimeSmart(track.duration))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
            }
            
            if let trackListNames, !trackListNames.isEmpty {
                Text("в треклисте: \(trackListNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
        }
    }
    
    private var rowHighlightColor: Color {
        if isHighlighted {
            return Color.gray.opacity(0.12)      // временная подсветка при открытом шите
        } else if isCurrent {
            return Color.accentColor.opacity(0.12) // активный трек
        } else {
            return Color.clear
        }
    }
}

