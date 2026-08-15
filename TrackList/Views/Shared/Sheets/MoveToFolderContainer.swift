//
//  MoveToFolderContainer.swift
//  TrackList
//
//  SwiftUI-контейнер feature-flow выбора папки назначения.
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI

/// Отображает готовый ScreenState и направляет typed actions в feature graph.
struct MoveToFolderContainer: View {

    /// Контейнер удерживает единственный feature graph на время immutable sheet route.
    @StateObject private var viewModel: MoveToFolderViewModel

    init(viewModel: MoveToFolderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Интерфейс

    var body: some View {
        let state = viewModel.state

        NavigationBarHost(
            title: state.navigationTitle,
            rightButtonImage: "checkmark",
            isRightEnabled: Binding(
                get: { state.canSubmit },
                set: { _ in }
            ),
            onClose: {
                viewModel.send(.closeTapped)
            },
            closeAccessibilityLabel: String(localized: "Cancel"),
            onRightTap: {
                viewModel.send(.submitTapped)
            },
            rightButtonAccessibilityLabel: state.navigationTitle
        ) {
            MoveToFolderSheet(
                rootNavigationTitle: state.navigationTitle,
                folderSnapshot: state.folderSnapshot,
                selectedFolderID: state.selectedFolderID,
                currentFolderID: state.currentFolderID,
                onFolderSelectionChanged: {
                    viewModel.send(.folderSelectionChanged($0))
                }
            )
        }
        .task {
            viewModel.send(.screenAppeared)
        }
        .onDisappear {
            viewModel.send(.sheetDisappeared)
        }
    }
}
