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
                leading: { EmptyView() },
                trailing: {
                    Menu {
                        Button {
                            SheetManager.shared.presentCreateTrackList()
                        } label: {
                            Label("Новый треклист", systemImage: "plus")
                    
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            )
    }
}

// MARK: - Modifier
extension View {
    
    func trackListsToolbar() -> some View {
        self.modifier(TrackListsToolbar())
    }
}
