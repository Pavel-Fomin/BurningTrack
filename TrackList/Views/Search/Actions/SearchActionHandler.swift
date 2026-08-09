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
    /// Состояние playback нужно только для проверки текущего результата поиска.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска и toggle не раскрывают ActionHandler-у PlayerViewModel.
    private let playbackController: any TrackPlaybackControlling
    private let navigationCoordinator: NavigationCoordinator
    private let sheetManager: SheetManager
    private let fileRenamer: TrackFileRenameActionHandler
    /// Общий обработчик «Избранного» не зависит от состояния конкретного экрана поиска.
    private let favoriteActionHandler: FavoriteTrackActionHandler

    init(
        viewModel: SearchViewModel,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        navigationCoordinator: NavigationCoordinator,
        sheetManager: SheetManager,
        fileRenamer: TrackFileRenameActionHandler,
        favoriteActionHandler: FavoriteTrackActionHandler
    ) {
        self.viewModel = viewModel
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.navigationCoordinator = navigationCoordinator
        self.sheetManager = sheetManager
        self.fileRenamer = fileRenamer
        self.favoriteActionHandler = favoriteActionHandler
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

        case .share(let result):
            TrackShareActionHandler.shared.shareLocalTrack(
                trackID: result.trackId
            )

        case .moveToFolder(let result):
            sheetManager.presentMoveToFolder(for: result)

        case .addToPlayer(let trackId):
            addToPlayer(trackId: trackId)

        case .addToTrackList(let result):
            sheetManager.presentAddToTrackList(for: result)

        case .toggleFavorite(let result):
            favoriteActionHandler.toggle(
                FavoriteTrackInput(playerTrack: result)
            )

        case .renameFile(let result, let strategy):
            renameFile(result, strategy: strategy)

        case .editTags(let result):
            sheetManager.presentTrackDetailForEditing(result)
        }
    }

    /// Запускает найденный трек без перехода в раздел фонотеки.
    private func playTrack(_ result: SearchTrackResult) {
        if playbackStateProvider.currentTrackId == result.trackId {
            playbackController.togglePlayPause()
            return
        }

        playbackController.play(
            track: result,
            context: [result],
            source: .playerQueue
        )
    }

    /// Добавляет найденный трек в плеер через общий executor приложения.
    private func addToPlayer(trackId: UUID) {
        Task {
            do {
                let result = try await AppCommandExecutor.shared.addTrackToPlayer(
                    trackId: trackId
                )
                AppCommandToastPresenter(
                    toastPresenter: ToastManager.shared
                ).present(result)
            } catch let appError as AppError {
                AppCommandToastPresenter(
                    toastPresenter: ToastManager.shared
                ).present(appError)
            } catch {
                ToastManager.shared.handle(
                    .operationFailed(
                        message: PlayerPresentationText.addTrackToPlayerFailedMessage
                    )
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
