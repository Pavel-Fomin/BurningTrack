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
                    Task { await addSelectedTracks() }
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
                        Task { await addSelectedTracks() }
                    }
                )
            }
        }
    }

    // MARK: - Actions

    /// Создаёт треклист с выбранными треками или добавляет их в существующий.
    private func addSelectedTracks() async {
        let selectedTracks = viewModel.selectedTracks

        guard !selectedTracks.isEmpty else {
            ToastManager.shared.handle(.operationFailed(message: "Нет выбранных треков"))
            return
        }

        switch data.mode {

        case .create(let name):
            do {
                let created = try TrackListsManager.shared.createTrackList(
                    from: selectedTracks,
                    withName: name
                )
                ToastManager.shared.handle(.trackListCreated(name: created.name))
            } catch let appError as AppError {
                PersistentLogger.log("NewTrackListSelectionContainer: create tracklist failed error=\(appError)")
                ToastManager.shared.handle(appError)
                return
            } catch {
                PersistentLogger.log("NewTrackListSelectionContainer: create tracklist failed error=\(error)")
                ToastManager.shared.handle(AppError.trackListSaveFailed)
                return
            }

        case .append(let trackListId):
            let trackListName: String
            do {
                trackListName = try TrackListsManager.shared
                    .loadTrackListMetas()
                    .first { $0.id == trackListId }?
                    .name ?? "Треклист"
            } catch let appError as AppError {
                ToastManager.shared.handle(appError)
                return
            } catch {
                ToastManager.shared.handle(AppError.trackListLoadFailed)
                return
            }

            do {
                let addedTracks = selectedTracks
                try TrackListsManager.shared.addTracks(
                    selectedTracks,
                    to: trackListId
                )
                await showAddedTracksToast(
                    addedTracks,
                    trackListName: trackListName
                )
            } catch let appError as AppError {
                PersistentLogger.log("NewTrackListSelectionContainer: add tracks failed error=\(appError)")
                ToastManager.shared.handle(appError)
                return
            } catch {
                PersistentLogger.log("NewTrackListSelectionContainer: add tracks failed error=\(error)")
                ToastManager.shared.handle(AppError.trackListSaveFailed)
                return
            }
        }

        SheetManager.shared.closeActive()
    }

    /// Показывает один Toast по результату добавления треков.
    private func showAddedTracksToast(
        _ addedTracks: [LibraryTrack],
        trackListName: String
    ) async {
        if addedTracks.count == 1, let track = addedTracks.first {
            let event = await TrackToastEventBuilder.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
            ToastManager.shared.handle(event)
            return
        }

        ToastManager.shared.handle(
            .tracksAddedToTrackList(
                count: addedTracks.count,
                name: trackListName
            )
        )
    }
}
