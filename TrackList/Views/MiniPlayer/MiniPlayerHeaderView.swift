//
//  MiniPlayerHeaderView.swift
//  TrackList
//
//  Верхняя часть мини-плеера.
//
//  Роль:
//  - отображает обложку и информацию о треке;
//  - содержит основные кнопки управления воспроизведением.
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI

struct MiniPlayerHeaderView: View {

    /// Смещение даёт обратную связь о направлении свайпа, не меняя компоновку кнопок.
    @State private var contentDragOffset: CGFloat = 0

    // MARK: - Input

    let artworkRequest: ArtworkRequest?
    let title: String
    let artist: String
    let isPlaying: Bool
    /// Переопределение цвета заголовка для специальных состояний мини-плеера.
    let titleColorOverride: Color?

    let onContentTap: () -> Void
    let onContentSwipePrevious: () -> Void
    let onContentSwipeNext: () -> Void
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {
            informationArea

            MiniPlayerTransportControlsView(
                isPlaying: isPlaying,
                onPrevious: onPrevious,
                onPlayPause: onPlayPause,
                onNext: onNext
            )
            // Сохраняем ширину зон управления при сжатии текста.
            .layoutPriority(1)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now Playing")
    }

    /// Объединяет обложку и метаданные в единую область управления без транспортных кнопок.
    private var informationArea: some View {
        Button(action: onContentTap) {
            HStack(spacing: 12) {
                artworkView

                VStack(alignment: .leading, spacing: 2) {
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(title)
                        // Название использует тот же шрифт, что и исполнитель.
                        .font(.caption)
                        .foregroundColor(
                            titleColorOverride ?? (artist.isEmpty ? .primary : .secondary)
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // Текст занимает только оставшееся место и не вытесняет кнопки.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: contentDragOffset)
        // Горизонтальный жест ограничен информационной областью,
        // чтобы не конкурировать с перемоткой и транспортными кнопками.
        .simultaneousGesture(contentSwipeGesture)
        .accessibilityLabel(isPlaying ? String(localized: "Pause") : String(localized: "Play"))
        .accessibilityValue([artist, title].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    /// Отделяет смену трека от вертикального жеста карточки по преобладающему направлению.
    private var contentSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > abs(verticalDistance) else {
                    contentDragOffset = 0
                    return
                }

                // Ограничиваем визуальное смещение порогом действия, чтобы не перекрывать кнопки.
                contentDragOffset = min(max(horizontalDistance, -48), 48)
            }
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let threshold: CGFloat = 48

                defer {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        contentDragOffset = 0
                    }
                }

                guard abs(horizontalDistance) > abs(verticalDistance),
                      abs(horizontalDistance) >= threshold else {
                    return
                }

                if horizontalDistance < 0 {
                    onContentSwipePrevious()
                } else {
                    onContentSwipeNext()
                }
            }
    }

    // MARK: - Artwork

    /// Показывает вращающуюся обложку текущего трека или статичную круглую заглушку.
    @ViewBuilder
    private var artworkView: some View {
        ArtworkPreparationView(request: artworkRequest) { image in
            RotatingArtworkView(
                image: image,
                isActive: true,
                isPlaying: isPlaying,
                size: 40,
                rpm: 10
            )
            .frame(width: 40, height: 40)
        } placeholder: {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
        }
    }
}
