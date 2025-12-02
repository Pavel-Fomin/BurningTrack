//
//  LibraryToolbar.swift
//  TrackList
//
//  Универсальный тулбар для раздела “Фонотека” и подпапок
//  Заголовок наследуется от названия текущей папки.
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct LibraryToolbar: ViewModifier {

    @ObservedObject private var nav = NavigationCoordinator.shared

    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: nav.currentTitle,
                leading: { EmptyView() },
                trailing: { EmptyView() }
            )
    }
}

// MARK: - Modifier

extension View {
    func libraryToolbar() -> some View {
        self.modifier(LibraryToolbar())
    }
}
