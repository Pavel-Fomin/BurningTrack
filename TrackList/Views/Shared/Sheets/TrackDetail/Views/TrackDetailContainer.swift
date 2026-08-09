//
//  TrackDetailContainer.swift
//  TrackList
//
//  SwiftUI-контейнер сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Связывает navigation UI с action-based Track Detail ViewModel.
struct TrackDetailContainer: View {
    /// Единственный владелец presentation state и edit draft.
    @StateObject private var viewModel: TrackDetailViewModel

    init(viewModel: TrackDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationBarHost(
            title: TrackDetailPresentationText.navigationTitle,
            rightButtonImage: rightButtonImage,
            isRightEnabled: .constant(isRightButtonEnabled),
            onClose: {
                viewModel.send(.closeTapped)
            },
            closeAccessibilityLabel: closeAccessibilityLabel,
            onRightTap: {
                switch viewModel.state.mode {
                case .view:
                    viewModel.send(.editTapped)

                case .edit:
                    viewModel.send(.saveTapped)
                }
            },
            rightButtonAccessibilityLabel: rightButtonAccessibilityLabel
        ) {
            TrackDetailSheet(
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
        .alert(
            TrackDetailPresentationText.trackIsPlayingTitle,
            isPresented: alertBinding(for: .stopPlayback)
        ) {
            Button(
                TrackDetailPresentationText.cancelAccessibilityLabel,
                role: .cancel
            ) {
                viewModel.send(.alertDismissed)
            }

            Button(TrackDetailPresentationText.stopAndSaveTitle) {
                viewModel.send(.stopPlaybackAndSaveConfirmed)
            }
        } message: {
            Text(TrackDetailPresentationText.stopPlaybackDescription)
        }
        .alert(
            TrackDetailPresentationText.fileNameConflictTitle,
            isPresented: alertBinding(for: .fileNameConflict)
        ) {
            Button(TrackDetailPresentationText.acknowledgeTitle, role: .cancel) {
                viewModel.send(.alertDismissed)
            }
        } message: {
            Text(TrackDetailPresentationText.fileNameConflictDescription)
        }
    }

    /// Образ универсальной правой кнопки зависит только от готового ScreenState.
    private var rightButtonImage: String? {
        switch viewModel.state.mode {
        case .view:
            return viewModel.state.canEnterEdit ? "pencil" : nil

        case .edit:
            return "checkmark"
        }
    }

    /// Доступность кнопки отражает готовые правила ViewModel.
    private var isRightButtonEnabled: Bool {
        switch viewModel.state.mode {
        case .view:
            return viewModel.state.canEnterEdit

        case .edit:
            return viewModel.state.canSave
        }
    }

    /// В edit Close отменяет draft, в view закрывает активный sheet.
    private var closeAccessibilityLabel: String {
        switch viewModel.state.mode {
        case .view:
            return TrackDetailPresentationText.closeAccessibilityLabel

        case .edit:
            return TrackDetailPresentationText.cancelAccessibilityLabel
        }
    }

    /// Подпись правой кнопки соответствует активному режиму.
    private var rightButtonAccessibilityLabel: String? {
        switch viewModel.state.mode {
        case .view:
            return viewModel.state.canEnterEdit
                ? TrackDetailPresentationText.editAccessibilityLabel
                : nil

        case .edit:
            return TrackDetailPresentationText.saveAccessibilityLabel
        }
    }

    /// Преобразует typed alert ScreenState в стандартный SwiftUI Binding.
    private func alertBinding(
        for alert: TrackDetailAlert
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.state.alert == alert },
            set: { isPresented in
                if !isPresented {
                    viewModel.send(.alertDismissed)
                }
            }
        )
    }
}
