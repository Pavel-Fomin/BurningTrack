//
//  NewTrackListSelectionContainer.swift
//  TrackList
//
//  Контейнер выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 29.04.2026.
//

import SwiftUI

struct NewTrackListSelectionContainer: View {

    // MARK: - Состояние

    /// ViewModel выбора уже собрана feature-factory и сохраняет выбор на время sheet-flow.
    @StateObject private var viewModel: NewTrackListSelectionViewModel
    /// Создаёт дочерние folder-экраны через существующую factory Library Tracks.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    // MARK: - Инициализация

    init(
        viewModel: NewTrackListSelectionViewModel,
        folderViewFactory: NewTrackListSelectionFolderViewFactory
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.folderViewFactory = folderViewFactory
    }

    // MARK: - Интерфейс

    var body: some View {
        let state = viewModel.state

        ZStack(alignment: .bottom) {
            NavigationBarHost(
                title: "Select Tracks",

                /// Кнопка подтверждения выбора треков.
                rightButtonImage: "checkmark",

                /// Пока кнопка активна только если выбран хотя бы один трек.
                isRightEnabled: Binding(
                    get: { state.canSubmit },
                    set: { _ in }
                ),

                /// Закрытие sheet’а без применения выбора.
                onClose: {
                    viewModel.handle(.cancel)
                },

                /// Применение выбранных треков после подтверждения.
                onRightTap: {
                    viewModel.handle(.submit)
                },
                showsRightButtonOnlyOnRoot: true
            ) {
                NewTrackListSelectionFolderListView(
                    folders: state.folders,
                    folderViewFactory: folderViewFactory,
                    selectionViewModel: viewModel
                )
            }
            

            if state.canSubmit {
                SelectionActionBar(
                    title: String(localized: "Selected"),
                    subtitle: TrackListPresentationText.selectedTracksCount(
                        state.selectedCount
                    ),
                    primaryTitle: String(localized: "Add"),
                    iconName: "music.note",
                    isPrimaryEnabled: state.canSubmit,
                    onPrimaryTap: {
                        viewModel.handle(.submit)
                    }
                )
            }
        }
        .task {
            viewModel.handle(.screenAppeared)
        }
        .onDisappear {
            viewModel.handle(.sheetDisappeared)
        }
    }
}
