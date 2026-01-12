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

    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: title,
                subtitle: subtitle,
                leading: { EmptyView() }
            )
    }
}

// MARK: - Modifier

extension View {

    func libraryToolbar(
        title: String,
        subtitle: String? = nil
    ) -> some View {
        self.modifier(
            LibraryToolbar(
                title: title,
                subtitle: subtitle
            )
        )
    }
}
