//
//  ToastView.swift
//  TrackList
//
//  Кастомный тост с обложкой, названием и сообщением.
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct ToastView: View {
    let data: ToastData

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Обложка
            if let image = data.artwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Название, артист и сообщение
            VStack(alignment: .leading, spacing: 2) {
                if let title = data.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                if let artist = data.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Text(data.message)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Сначала растягиваем содержимое
        .padding(12)                                     // Потом паддинг
        .background(.ultraThinMaterial)                  // Потом фон
        .background(Color.black.opacity(0.85))           // Затем чёрная подложка
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)                         // И последний внешний паддинг
    }
}
