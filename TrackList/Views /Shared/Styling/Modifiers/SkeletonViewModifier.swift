//
//  SkeletonViewModifier.swift
//  TrackList
//
//  Created by Pavel Fomin on 23.11.2025.
//

import Foundation
import SwiftUI

struct SkeletonViewModifier: ViewModifier {
    @State private var isAnimating: Bool = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                GeometryReader { geo in
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.1),
                                Color.gray.opacity(0.3)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width)
                        .offset(x: isAnimating ? geo.size.width : -geo.size.width)
                        .animation(
                            Animation.linear(duration: 1.2)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                    }
                }
                .clipped()
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func skeleton() -> some View {
        self.modifier(SkeletonViewModifier())
    }
}
