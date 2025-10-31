//
//  LibraryHeaderView.swift
//  TrackList
//
//  Заголовок раздела “Фонотека”
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct LibraryHeaderView: View {
    var onAddFolder: () -> Void
    @ObservedObject var coordinator: LibraryCoordinator
    
    var body: some View {
        ScreenHeaderView(
            title: titleText,
            leading: {
                if !isAtRoot {
                    Button(action: { coordinator.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            },
            trailing: { EmptyView() }
        )
    }
    

    // MARK: - Локальные вычисления
    
    private var isAtRoot: Bool {
        if case .root = coordinator.state { return true }
        return false
    }

    private var titleText: String {
        switch coordinator.state {
        case .root:
            return "Фонотека"
        case .folder(let f), .tracks(let f):
            return f.name
        }
    }
}



