//
//  MiniPlayerHeaderView.swift
//  TrackList
//
//  Верхняя часть мини-плеера.
//
//  Роль:
//  - отображает обложку и информацию о треке
//  - обрабатывает tap (play/pause)
//  - обрабатывает свайп влево/вправо (следующий/предыдущий)
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI
import AVKit

struct MiniPlayerHeaderView: View {

    let artwork: UIImage?
    let title: String
    let artist: String

    let onTap: () -> Void
    let onSwipeNext: () -> Void
    let onSwipePrevious: () -> Void

    @State private var dragOffsetX: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {

            HStack(spacing: 12) {

                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                }

                VStack(alignment: .leading, spacing: 2) {

                    Text(artist.isEmpty ? "Неизвестный артист" : artist)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .offset(x: dragOffsetX)
            .animation(.spring(), value: dragOffsetX)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            Spacer()

            AVRoutePickerViewWrapper()
                .frame(width: 24, height: 24)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffsetX = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 30

                    if value.translation.width > threshold {
                        onSwipeNext()
                    } else if value.translation.width < -threshold {
                        onSwipePrevious()
                    }

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffsetX = 0
                    }
                }
        )
    }
}
