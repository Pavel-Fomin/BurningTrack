//
//  BatchFilenameRenameContainer.swift
//  TrackList
//
//  SwiftUI-контейнер feature массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Связывает navigation UI с feature-local ViewModel без раскрытия draft в View.
struct BatchFilenameRenameContainer: View {
    /// Контейнер удерживает единственный ViewModel на время immutable sheet route.
    @StateObject private var viewModel: BatchFilenameRenameViewModel

    init(viewModel: BatchFilenameRenameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationBarHost(
            title: FileRenamePresentationText.batchRenameTitle,
            subtitle: FileRenamePresentationText.batchRenameSubtitle,
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(!viewModel.state.isDismissDisabled),
            onClose: {
                viewModel.send(.closeTapped)
            },
            closeAccessibilityLabel: String(localized: "Cancel"),
            onRightTap: {
                viewModel.send(.closeTapped)
            },
            rightButtonAccessibilityLabel: String(localized: "Done")
        ) {
            BatchFilenameRenameSheet(
                state: viewModel.state,
                send: viewModel.send
            )
        }
        .interactiveDismissDisabled(viewModel.state.isDismissDisabled)
        .onAppear {
            viewModel.send(.appeared)
        }
        .onDisappear {
            viewModel.send(.sheetDisappeared)
        }
    }
}
