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
                    .tint(action.tint)
                }
            }
        }
        
        .listRowBackground(
            isCurrent ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }

    
// MARK: - Обложка
    
    private var artworkView: some View {
        ZStack {
            if let artwork = artwork {
                RotatingArtworkLayerView(
                    image: UIImage(cgImage: artwork),
                    isActive: isCurrent,
                    isPlaying: isPlaying,
                    size: 48,
                    rpm: 10 // скорость ~10 оборотов/мин (≈60°/сек)
                )
                .frame(width: 48, height: 48)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                // Иконка показывается ТОЛЬКО у плейсхолдера
                if isCurrent {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                        .shadow(radius: 1)
                }
            }
        }
    }
    
    
// MARK: - Вращение обложки
    
    private struct RotatingIfActive: ViewModifier {
        let isActive: Bool
        let isPlaying: Bool
        let speed: Double = 30 // градусов/сек

        @State private var pausedAngle: Double = 0
        @State private var playStartDate: Date? = nil

        func body(content: Content) -> some View {
            TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
                let now = timeline.date
                let angle: Double = {
                    guard isActive else { return 0 } // неактивные — без поворота
                    if let start = playStartDate {
                        let delta = now.timeIntervalSince(start) * speed
                        return fmod(pausedAngle + delta, 360)
                    } else {
                        return pausedAngle
                    }
                }()

                content
                    .rotationEffect(.degrees(angle), anchor: .center)
                    // без .animation — дерганье уходит
            }
            .onAppear {
                if isActive && isPlaying { playStartDate = Date() }
            }
            .onChange(of: isPlaying) { _, newValue in
                guard isActive else { return }
                if newValue {
                    playStartDate = Date()
                } else {
                    if let start = playStartDate {
                        let delta = Date().timeIntervalSince(start) * speed
                        pausedAngle = fmod(pausedAngle + delta, 360)
                    }
                    playStartDate = nil
                }
            }
            .onChange(of: isActive) { _, active in
                // при смене активной строки — сброс старой и старт новой
                if active {
                    pausedAngle = 0
                    playStartDate = isPlaying ? Date() : nil
                } else {
                    pausedAngle = 0
                    playStartDate = nil
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
    }

