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

    let data: NewTrackListSelectionSheetData

    /// Общий обработчик переименования файлов треков.
    let renameActionHandler: TrackFileRenameActionHandler

    // MARK: - State

    /// Количество выбранных треков.
    /// Состояние выбора треков внутри sheet.
    @StateObject private var viewModel = NewTrackListSelectionViewModel()

    // MARK: - UI

    var body: some View {
        let state = NewTrackListSelectionStateBuilder().build(
            selectedCount: viewModel.selectedCount,
            mode: data.mode
        )
        let actionHandler = NewTrackListSelectionActionHandler(
            mode: data.mode,
            selectedTracksProvider: {
                viewModel.selectedTracks
            }
        )

        ZStack(alignment: .bottom) {
            NavigationBarHost(
                title: "Выберите треки",

                /// Кнопка подтверждения выбора треков.
                rightButtonImage: "checkmark",

                /// Пока кнопка активна только если выбран хотя бы один трек.
                isRightEnabled: Binding(
                    get: { state.canSubmit },
                    set: { _ in }
                ),

                /// Закрытие sheet’а без применения выбора.
                onClose: {
                    actionHandler.handle(.cancel)
                },

                /// Применение выбранных треков после подтверждения.
                onRightTap: {
                    actionHandler.handle(.submit)
                },
                showsRightButtonOnlyOnRoot: true
            ) {
                NewTrackListSelectionFolderListView(
                    folders: MusicLibraryManager.shared.attachedFolders,
                    renameActionHandler: renameActionHandler,
                    selectionViewModel: viewModel
                )
            }
            

            if state.canSubmit {
                SelectionActionBar(
                    title: "Выбрано",
                    subtitle: "\(viewModel.selectedCount) треков",
                    primaryTitle: state.buttonTitle,
                    iconName: "music.note",
                    isPrimaryEnabled: state.canSubmit,
                    onPrimaryTap: {
                        actionHandler.handle(.submit)
                    }
                )
            }
        }
    }
}
