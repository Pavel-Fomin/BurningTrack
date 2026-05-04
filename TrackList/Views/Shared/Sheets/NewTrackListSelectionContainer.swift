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

    // MARK: - State

    /// Количество выбранных треков.
    /// Состояние выбора треков внутри sheet.
    @StateObject private var viewModel = NewTrackListSelectionViewModel()
    // MARK: - UI

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationBarHost(
                title: "Выберите треки",

                /// Кнопка подтверждения выбора треков.
                rightButtonImage: "checkmark",

                /// Пока кнопка активна только если выбран хотя бы один трек.
                isRightEnabled: Binding(
                    get: { viewModel.selectedCount > 0 },
                    set: { _ in }
                ),

                /// Закрытие sheet’а без применения выбора.
                onClose: {
                    SheetManager.shared.closeActive()
                },

                /// Применение выбранных треков после подтверждения.
                onRightTap: {
                    addSelectedTracks()
                },
                showsRightButtonOnlyOnRoot: true
            ) {
                NewTrackListSelectionFolderListView(
                    folders: MusicLibraryManager.shared.attachedFolders,
                    selectionViewModel: viewModel
                )
            }
            

            if viewModel.selectedCount > 0 {
                SelectionActionBar(
                    selectedCount: viewModel.selectedCount,
                    title: "Выбрано",
                    subtitle: "\(viewModel.selectedCount) треков",
                    primaryTitle: "Добавить",
                    isPrimaryEnabled: viewModel.selectedCount > 0,
                    onPrimaryTap: {
                        addSelectedTracks()
                    }
                )
            }
        }
    }

    // MARK: - Actions

    /// Создаёт треклист с выбранными треками или добавляет их в существующий.
    private func addSelectedTracks() {
        let selectedTracks = viewModel.selectedTracks

        guard !selectedTracks.isEmpty else { return }

        switch data.mode {

        case .create(let name):
            do {
                _ = try TrackListsManager.shared.createTrackList(
                    from: selectedTracks,
                    withName: name
                )
            } catch {
                PersistentLogger.log("NewTrackListSelectionContainer: create tracklist failed error=\(error)")
                return
            }

        case .append(let trackListId):
            do {
                try TrackListsManager.shared.addTracks(
                    selectedTracks,
                    to: trackListId
                )
            } catch {
                PersistentLogger.log("NewTrackListSelectionContainer: add tracks failed error=\(error)")
                return
            }
        }

        SheetManager.shared.closeActive()
    }
}
