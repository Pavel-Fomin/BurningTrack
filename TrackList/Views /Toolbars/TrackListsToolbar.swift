//
//  TrackListsToolbar.swift
//  TrackList
//
//  Тулбар для раздела “Треклисты”
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct TrackListsToolbar: ViewModifier {

    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: "Треклисты",
                leading: { EmptyView() }
            )
    }
}

// MARK: - Modifier
extension View {
    
    func trackListsToolbar() -> some View {
        self.modifier(TrackListsToolbar())
    }
}
