//
//  LibraryFoldersSkeletonView.swift
//  TrackList
//
//  Скелетон для списка корневых папок фонотеки
//
//  Created by Pavel Fomin on 23.11.2025.
//

import Foundation
import SwiftUI

struct LibraryFoldersSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .frame(width: 24, height: 24)
                        .opacity(0.3)
                        .modifier(SkeletonViewModifier())   // 👈 анимация

                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .frame(height: 14)
                            .opacity(0.3)
                            .modifier(SkeletonViewModifier()) // 👈 анимация

                        RoundedRectangle(cornerRadius: 4)
                            .frame(width: 120, height: 10)
                            .opacity(0.2)
                            .modifier(SkeletonViewModifier()) // 👈 анимация
                    }
                }
                .padding(.vertical, 6)
                .redacted(reason: .placeholder)
            }
        }
        .scrollDisabled(true)
    }
}
