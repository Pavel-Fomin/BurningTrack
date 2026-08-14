//
//  MiniPlayerHeaderView.swift
//  TrackList
//
//  Верхняя часть мини-плеера.
//
//  Роль:
//  - отображает обложку и информацию о треке;
//  - содержит действие изменения состояния «Избранного».
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI

struct MiniPlayerHeaderView: View {

    /// Смещение даёт обратную связь о направлении свайпа, не меняя компоновку заголовка.
    @State private var contentDragOffset: CGFloat = 0

    // MARK: - Входные данные

    let artworkRequest: ArtworkRequest?
    let title: String
    let artist: String
    let isPlaying: Bool
    /// Отражает подтверждённое состояние текущего трека в системном треклисте «Избранное».
    let isFavorite: Bool
    /// Не позволяет изменять избранное, пока у плеера нет конкретного трека.
    let isFavoriteEnabled: Bool
    /// Переопределение цвета заголовка для специальных состояний мини-плеера.
    let titleColorOverride: Color?

    let onContentTap: () -> Void
    let onContentSwipePrevious: () -> Void
    let onContentSwipeNext: () -> Void
    let onFavorite: () -> Void

    // MARK: - Интерфейс

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            informationArea

            // Кнопка остаётся по центру строки с обложкой и метаданными трека.
            favoriteButton
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now Playing")
    }

    /// Переключает состояние текущего трека, не изменяя жесты управления воспроизведением.
    private var favoriteButton: some View {
        Button(action: onFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isFavoriteEnabled)
        .foregroundStyle(isFavorite ? Color.red : Color.primary.opacity(0.65))
        .accessibilityLabel(
            isFavorite
                ? "Удалить из Избранного"
                : "Добавить в Избранное"
        )
        .accessibilityValue(isFavorite ? "В Избранном" : "Не в Избранном")
    }

    /// Объединяет обложку и метаданные в единую область управления воспроизведением.
    private var informationArea: some View {
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
            // Текст занимает только оставшееся место и не вытесняет кнопку избранного.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .offset(x: contentDragOffset)
        // Единый жест исключает одновременное срабатывание нажатия и смены трека.
        .gesture(contentInteractionGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onContentTap()
        }
        .accessibilityLabel(isPlaying ? String(localized: "Pause") : String(localized: "Play"))
        .accessibilityValue([artist, title].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    /// Разделяет нажатие и смену трека, не перехватывая вертикальный жест карточки.
    private var contentInteractionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) > abs(verticalDistance) else {
                    contentDragOffset = 0
                    return
                }

                // Ограничиваем визуальное смещение порогом действия, чтобы не перекрывать кнопку избранного.
                contentDragOffset = min(max(horizontalDistance, -48), 48)
            }
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let swipeThreshold: CGFloat = 48
                let tapThreshold: CGFloat = 10

                defer {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        contentDragOffset = 0
                    }
                }

                let totalDistance = hypot(horizontalDistance, verticalDistance)

                guard totalDistance >= tapThreshold else {
                    onContentTap()
                    return
                }

                guard abs(horizontalDistance) > abs(verticalDistance),
                      abs(horizontalDistance) >= swipeThreshold else {
                    return
                }

                if horizontalDistance < 0 {
                    onContentSwipePrevious()
                } else {
                    onContentSwipeNext()
                }
            }
    }

    // MARK: - Обложка

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
