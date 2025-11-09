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
    var trackListName: String
    var onExport: () -> Void
    var onRename: () -> Void

    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: trackListName,
                leading: { EmptyView() },
                trailing: {
                    Menu {
                        Button("Экспорт", action: onExport)
                        Button("Переименовать", action: onRename)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            )
    }
}

extension View {
    func trackListToolbar(
        trackListName: String,
        onExport: @escaping () -> Void,
        onRename: @escaping () -> Void
    ) -> some View {
        self.modifier(TrackListToolbar(
            trackListName: trackListName,
            onExport: onExport,
            onRename: onRename
        ))
    }
}
