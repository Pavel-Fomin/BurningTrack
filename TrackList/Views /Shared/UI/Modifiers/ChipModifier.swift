//
//  ChipModifier.swift
//  TrackList
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

struct ChipModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
            )
            .foregroundColor(isSelected ? .white : .primary)
    }
}

extension View {
    func chipStyle(isSelected: Bool) -> some View {
        self.modifier(ChipModifier(isSelected: isSelected))
    }
}
