//
//  BatchTagEditContainer.swift
//  TrackList
//
//  SwiftUI-контейнер сценария массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Связывает navigation UI со state-based Batch Tag Edit ViewModel.
struct BatchTagEditContainer: View {
    /// Единственный владелец draft и асинхронного lifecycle feature.
    @StateObject private var viewModel: BatchTagEditViewModel

    init(viewModel: BatchTagEditViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationBarHost(
            title: BatchTagEditPresentationText.navigationTitle,
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(viewModel.state.canSave),
            onClose: {
                viewModel.send(.closeTapped)
            },
            closeAccessibilityLabel: String(localized: "Cancel"),
            onRightTap: {
                viewModel.send(.saveTapped)
            },
            rightButtonAccessibilityLabel: String(localized: "Save")
        ) {
            BatchTagEditSheet(
                state: viewModel.state,
                send: viewModel.send
            )
        }
        .task {
            viewModel.send(.appeared)
        }
        .onDisappear {
            viewModel.send(.sheetDisappeared)
        }
    }
}
