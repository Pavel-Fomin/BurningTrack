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

// MARK: - Обложка (только для .track)
            
            if case .track = data.style, let image = data.artwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            
// MARK: - Текстовая часть
            
            VStack(alignment: .leading, spacing: 2) {
                switch data.style {
                case let .track(title, artist):
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)

                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                case .trackList:
                    EmptyView()
                }

                Text(data.message)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }
}
