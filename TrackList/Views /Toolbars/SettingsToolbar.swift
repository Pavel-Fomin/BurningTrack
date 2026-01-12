//
//  SettingsToolbar.swift
//  TrackList
//
//  Тулбар для раздела “Настройки”
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct SettingsToolbar: ViewModifier {

// MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: "Настройки",
                leading: { EmptyView() }
            )
    }
}

// MARK: - Modifier

extension View {

    func settingsToolbar() -> some View {
        self.modifier(SettingsToolbar())
    }
}
