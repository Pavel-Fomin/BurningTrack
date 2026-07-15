//
//  SearchActionHandler.swift
//  TrackList
//
//  Обработчик действий раздела поиска.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation

@MainActor
final class SearchActionHandler {
    private let viewModel: SearchViewModel
    private let playerViewModel: PlayerViewModel
    private let navigationCoordinator: NavigationCoordinator
    private let sheetManager: SheetManager
    private let sheetActionCoordinator: SheetActionCoordinator
    private let fileRenamer: TrackFileRenameActionHandler

    init(
        viewModel: SearchViewModel,
        playerViewModel: PlayerViewModel,
        navigationCoordinator: NavigationCoordinator,
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator,
        fileRenamer: TrackFileRenameActionHandler
    ) {
        self.viewModel = viewModel
        self.playerViewModel = playerViewModel
        self.navigationCoordinator = navigationCoordinator
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.fileRenamer = fileRenamer
    }

    /// Передаёт действия View в SearchViewModel без бизнес-логики в SwiftUI.
    func handle(_ action: SearchAction) {
        switch action {
        case .appeared:
            viewModel.refreshIfNeeded()

        case .queryChanged(let query):
            viewModel.updateQuery(query)

        case .clearQuery:
            viewModel.clearQuery()

        case .selectTrackFilter(let field):
            viewModel.selectTrackFilter(field: field)

        case .selectSortMode(let mode):
            viewModel.selectSortMode(mode)

        case .requestTrackSnapshot(let trackId):
            viewModel.requestSnapshotIfNeeded(for: trackId)

        case .playTrack(let result):
            playTrack(result)

        case .openFolder(let result):
            openFolder(result)

        case .openTrackList(let result):
            openTrackList(result)

        case .showDetails(let result):
            sheetManager.presentTrackDetail(result)

        case .moveToFolder(let result):
            sheetActionCoordinator.handle(
                action: .moveToFolder,
                track: result,
                context: .library
            )

        case .addToPlayer(let trackId):
            addToPlayer(trackId: trackId)

        case .addToTrackList(let result):
            sheetManager.presentAddToTrackList(for: result)

        case .renameFile(let result, let strategy):
            renameFile(result, strategy: strategy)

        case .editTags(let result):
            sheetManager.presentTrackDetailForEditing(result)
        }
    }

    /// Запускает найденный трек без перехода в раздел фонотеки.
    private func playTrack(_ result: SearchTrackResult) {
        if playerViewModel.isCurrent(result, in: .unknown) {
            playerViewModel.togglePlayPause()
            return
        }

        playerViewModel.play(
            track: result,
            context: [result]
        )
    }

    /// Добавляет найденный трек в плеер через общий executor приложения.
    private func addToPlayer(trackId: UUID) {
        Task {
            do {
                try await AppCommandExecutor.shared.addTrackToPlayer(
                    trackId: trackId
                )
            } catch let appError as AppError {
                ToastManager.shared.handle(appError)
            } catch {
                ToastManager.shared.handle(
                    .operationFailed(message: "Не удалось добавить трек в плеер")
                )
            }
        }
    }

    /// Передаёт переход к папке на уровень общей навигации приложения.
    private func openFolder(_ result: SearchFolderResult) {
        navigationCoordinator.openLibraryFolderFromApp(result.id)
    }

    /// Передаёт переход к треклисту на уровень общей навигации приложения.
    private func openTrackList(_ result: SearchTrackListResult) {
        navigationCoordinator.openTrackListFromApp(result.id)
    }

    /// Запускает общий сценарий переименования файла без runtime snapshot.
    private func renameFile(
        _ result: SearchTrackResult,
        strategy: FileRenameStrategy
    ) {
        let request = TrackFileRenameRequest(
            trackId: result.trackId,
            rowId: result.id,
            currentFileName: result.fileName,
            artist: result.artist,
            title: result.title,
            strategy: strategy
        )

        fileRenamer.handle(request)
    }
}
