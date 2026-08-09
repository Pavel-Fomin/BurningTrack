//
//  RenameTrackFileContainer.swift
//  TrackList
//
//  UI-контейнер ручного переименования файла трека.
//  Передаёт готовое presentation-state и typed-действия между ViewModel и SwiftUI-формой.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import SwiftUI

struct RenameTrackFileContainer: View {

    /// Готовая ViewModel формы, собранная feature factory.
    @StateObject private var viewModel: RenameTrackFileViewModel
    /// Фокус остаётся UI-специфичным состоянием контейнера.
    @FocusState private var isFileNameFocused: Bool

    init(viewModel: RenameTrackFileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: FileRenamePresentationText.renameFileTitle,
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(viewModel.state.isRenameEnabled),
            onClose: {
                isFileNameFocused = false
                viewModel.send(.close)
            },
            closeAccessibilityLabel: String(localized: "Cancel"),
            onRightTap: {
                viewModel.send(.rename)
            },
            rightButtonAccessibilityLabel: String(localized: "Rename")
        ) {
            RenameTrackFileSheet(
                fileName: fileName,
                isFileNameFocused: $isFileNameFocused
            )
        }
        .alert(
            alertTitle,
            isPresented: isAlertPresented,
            actions: alertActions,
            message: alertMessage
        )
        .onDisappear {
            viewModel.send(.sheetDisappeared)
        }
    }

    /// Связывает TextField с presentation-state через typed action.
    private var fileName: Binding<String> {
        Binding(
            get: { viewModel.state.fileName },
            set: { viewModel.send(.fileNameChanged($0)) }
        )
    }

    /// Связывает показ системного alert с единым типизированным состоянием.
    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.alert != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.send(.dismissAlert)
                }
            }
        )
    }

    /// Возвращает локализованный заголовок для активного состояния alert.
    private var alertTitle: String {
        switch viewModel.state.alert {
        case .stopPlayback:
            FileRenamePresentationText.stopPlaybackTitle
        case .fileNameConflict:
            FileRenamePresentationText.nameConflictTitle
        case nil:
            ""
        }
    }

    /// Строит кнопки системного alert только из presentation-state.
    @ViewBuilder
    private func alertActions() -> some View {
        switch viewModel.state.alert {
        case .stopPlayback:
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.send(.dismissAlert)
            }

            Button(FileRenamePresentationText.stopAndRenameTitle) {
                viewModel.send(.confirmStopPlayback)
            }

        case .fileNameConflict:
            Button(String(localized: "Close"), role: .cancel) {
                viewModel.send(.dismissAlert)
            }

        case nil:
            EmptyView()
        }
    }

    /// Возвращает локализованное описание для активного состояния alert.
    @ViewBuilder
    private func alertMessage() -> some View {
        switch viewModel.state.alert {
        case .stopPlayback:
            Text(FileRenamePresentationText.stopPlaybackDescription)
        case .fileNameConflict:
            Text(FileRenamePresentationText.nameConflictDescription)
        case nil:
            EmptyView()
        }
    }
}
