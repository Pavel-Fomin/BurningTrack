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

enum TrackRowSelectionPlacement {
    case leading
    case trailing
}

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
    let selectionPlacement: TrackRowSelectionPlacement
    
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
        selectionPlacement: TrackRowSelectionPlacement = .leading,
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
        self.selectionPlacement = selectionPlacement
        self.trackListNames = trackListNames
        self.useNativeSwipeActions = useNativeSwipeActions
    }
    // MARK: - UI

    /// Есть ли отображаемый исполнитель
    private var hasArtist: Bool {
        guard let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return !artist.isEmpty && artist != "неизвестен"
    }

    /// Формат файла для правой колонки метаданных
    private var fileFormatLabel: String? {
        let extensionValue = (track.fileName as NSString).pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extensionValue.isEmpty else { return nil }
        return extensionValue
    }

    /// Есть ли расширенный контент, который делает строку выше обложки
    private var hasExtendedContent: Bool {
        guard let trackListNames else { return false }
        return !trackListNames.isEmpty
    }

    /// Вертикальное выравнивание строки: короткие строки центрируются, расширенные прижимаются к верху
    private var rowContentAlignment: VerticalAlignment {
        hasExtendedContent ? .top : .center
    }

    var body: some View {
        HStack(alignment: rowContentAlignment, spacing: 12) {

            // Radio (только в режиме выбора)
            if showsSelection && selectionPlacement == .leading {
                selectionButton
            }

            // Левая зона — обложка
            artworkView
                .contentShape(Rectangle())
                .onTapGesture {
                    guard track.isAvailable else {
                        ToastManager.shared.handle(
                            .trackUnavailable(title: track.title ?? track.fileName)
                        )
                        return
                    }
                    onArtworkTap?()
                }

            // Правая зона — информация о треке
            trackInfoView
                .contentShape(Rectangle())
                .onTapGesture {
                    guard track.isAvailable else {
                        ToastManager.shared.handle(
                            .trackUnavailable(title: track.title ?? track.fileName)
                        )
                        return
                    }
                    onRowTap()
                }

            if showsSelection && selectionPlacement == .trailing {
                selectionButton
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 4)
        .opacity(track.isAvailable ? 1 : 0.4)
        .listRowBackground(rowHighlightColor)
    }

    private var selectionButton: some View {
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
        HStack(alignment: rowContentAlignment, spacing: 8) {
            leftTextColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            metadataColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Левая колонка с основным текстом трека
    private var leftTextColumn: some View {
        VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
            if hasArtist, let artistText = artist {
                Text(artistText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Text(title ?? track.fileName)
                .font(hasArtist ? .footnote : .subheadline)
                .foregroundColor(hasArtist ? .secondary : .primary)
                .lineLimit(1)

            if let trackListNames, !trackListNames.isEmpty {
                Text("уже в: \(trackListNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.top, 4)
            }
        }
    }

    /// Правая колонка с техническими метаданными трека
    private var metadataColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let fileFormatLabel {
                Text(fileFormatLabel)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.65))
                    .lineLimit(1)
            }

            Text(formatTimeSmart(duration ?? track.duration))
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
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
