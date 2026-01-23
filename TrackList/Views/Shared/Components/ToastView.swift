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
    
    private let height: CGFloat = 64
    private let rightWidth: CGFloat = 120
    
    
    // MARK: - UI
    var body: some View {
        HStack(spacing: 12) {
            
            // Left block (50%)
            HStack(spacing: 12) {
                
                if let artworkImage = data.artworkImage {
                    
                    // Обложка
                    artworkImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        
                           // ARTIST
                           Text(artistText)
                               .font(.subheadline.weight(.semibold))
                               .foregroundStyle(.primary)
                               .opacity(0.8)
                               .lineLimit(1)
                               .truncationMode(.tail)

                           // TITLE
                           Text(titleText)
                               .font(.caption)
                               .foregroundStyle(.primary)
                               .opacity(0.8)
                               .lineLimit(1)
                               .truncationMode(.tail)
                       }
                    
                } else {
                    Text(data.message)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right block (50%)
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                if data.artworkImage != nil {
                    Text(data.message)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Text mapping
    
    private var titleText: String {
        switch data.style {
        case let .track(title, _):
            return title
        case let .trackList(name):
            return name
        }
    }
    
    private var artistText: String {
        switch data.style {
        case let .track(_, artist):
            return artist.isEmpty ? " " : artist
        case .trackList:
            return " "
        }
    }
}
