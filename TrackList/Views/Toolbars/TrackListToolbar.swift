//
//  TrackListToolbar.swift
//  TrackList
//
//  Тулбар для отдельного треклиста
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct TrackListToolbar: ViewModifier {

    @ObservedObject var viewModel: TrackListViewModel
    let onExport: () -> Void
    let onRename: () -> Void

    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: viewModel.name,
                leading: { EmptyView() }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Экспорт", action: onExport)
                        Button("Переименовать", action: onRename)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
    }
}

// MARK: - Modifier

extension View {

    func trackListToolbar(
        viewModel: TrackListViewModel,
        onExport: @escaping () -> Void,
        onRename: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TrackListToolbar(
                viewModel: viewModel,
                onExport: onExport,
                onRename: onRename
            )
        )
    }
}
