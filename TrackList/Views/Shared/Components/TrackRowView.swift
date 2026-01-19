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

struct TrackRowView: View {

    // MARK: - Входные параметры

    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let isHighlighted: Bool
    let artwork: UIImage?
    let title: String?
    let artist: String?
    let duration: Double?
    let onRowTap: () -> Void          /// Тап по правой части строки (воспроизведение / пауза)
    let onArtworkTap: (() -> Void)?   /// Тап по обложке (например, открытие экрана "О треке")
    let showsSelection: Bool          /// Показывать radio или нет
    let isSelected: Bool              /// Radio (пустой / выбранный)
    let onToggleSelection: (() -> Void)?
    
    var trackListNames: [String]? = nil
    var useNativeSwipeActions: Bool = false

    
    init(
        track: any TrackDisplayable,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        artwork: UIImage?,
        title: String?,
        artist: String?,
        duration: Double?,
        onRowTap: @escaping () -> Void,
        onArtworkTap: (() -> Void)?,
        showsSelection: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil,
        trackListNames: [String]? = nil,
        useNativeSwipeActions: Bool = false
    ) {
        self.track = track
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.isHighlighted = isHighlighted
        self.artwork = artwork
        self.title = title
        self.artist = artist
        self.duration = duration
        self.onRowTap = onRowTap
        self.onArtworkTap = onArtworkTap
        self.showsSelection = showsSelection
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
        self.trackListNames = trackListNames
        self.useNativeSwipeActions = useNativeSwipeActions
    }
    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {

            HStack(spacing: 12) {

                // Radio (только в режиме выбора)
                if showsSelection {
                    Button {
                        guard !isCurrent else { return }   // на всякий случай
                        onToggleSelection?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(
                                isCurrent
                                    ? .secondary
                                    : (isSelected ? .green : .secondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)         // ← фикс: одинаково для всех строк
                    .contentShape(Rectangle())
                    .disabled(isCurrent)                  // ← текущий трек не выбирается
                }

                // Левая зона — обложка
                artworkView
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard track.isAvailable else {
                            print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                            return
                        }
                        onArtworkTap?()
                    }

                // Правая зона — информация о треке
                trackInfoView
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard track.isAvailable else {
                            print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                            return
                        }
                        onRowTap()
                    }
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 4)
        .opacity(track.isAvailable ? 1 : 0.4)
        .listRowBackground(rowHighlightColor)
    }

    // MARK: - Обложка

    private var artworkView: some View {
        ZStack {
            if let artwork {
                RotatingArtworkView(
                    image: artwork,
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

    // MARK: - Информация о треке

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

                Text(formatTimeSmart(duration ?? track.duration))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let trackListNames, !trackListNames.isEmpty {
                Text("уже в: \(trackListNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Подсветка строки

    private var rowHighlightColor: Color {
        if isHighlighted {
            return Color.gray.opacity(0.12)          // Подсветка при открытом шите
        } else if isCurrent {
            return Color.accentColor.opacity(0.12)   // Подсветка текущего трека
        } else {
            return Color.clear
        }
    }
}
