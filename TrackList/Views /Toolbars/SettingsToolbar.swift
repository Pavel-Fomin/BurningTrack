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
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: "Настройки",
                leading: { EmptyView() },
                trailing: { EmptyView() }
            )
    }
}

extension View {
    func settingsToolbar() -> some View {
        self.modifier(SettingsToolbar())
    }
}

