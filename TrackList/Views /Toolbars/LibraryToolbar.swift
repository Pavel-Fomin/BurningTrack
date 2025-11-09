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
    @ObservedObject var coordinator: LibraryCoordinator
    var onAddFolder: () -> Void

    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: titleText,
                leading: {
                    if !isAtRoot {
                        Button {
                            coordinator.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                },
                trailing: {
                    EmptyView() // временно без кнопок
                }
            )
    }


// MARK: - Вычисления

    private var isAtRoot: Bool {
        if case .root = coordinator.state { return true }
        return false
    }

    private var titleText: String {
        switch coordinator.state {
        case .root:
            return "Фонотека"
        case .folder(let folder), .tracks(let folder):
            return folder.name
        }
    }
}


// MARK: - Расширение для вызова

extension View {
    func libraryToolbar(
        coordinator: LibraryCoordinator,
        onAddFolder: @escaping () -> Void
    ) -> some View {
        self.modifier(LibraryToolbar(coordinator: coordinator, onAddFolder: onAddFolder))
    }
}
