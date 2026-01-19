//
//  AppSheetContainer.swift
//  TrackList
//
//  Унифицированный iOS 26-style sheet
//
//  Created by Pavel Fomin
//

import SwiftUI

struct AppSheetContainer<Content: View>: View {

    let detents: Set<PresentationDetent>
    let content: Content

    init(
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: () -> Content
    ) {
        self.detents = detents
        self.content = content()
    }

    var body: some View {
        content
            .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .presentationDetents(detents)
            .presentationDragIndicator(.hidden)
            .presentationBackground(
                detents.contains(.large)
                ? Color(.systemGroupedBackground)
                : .clear
            )
    }
}
