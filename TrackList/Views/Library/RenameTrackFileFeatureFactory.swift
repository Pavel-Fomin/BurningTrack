//
//  RenameTrackFileFeatureFactory.swift
//  TrackList
//
//  Собирает production graph sheet-flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Собирает только feature Rename Track File из уже подготовленных production-зависимостей.
@MainActor
struct RenameTrackFileFeatureFactory {
    /// Проверяет занятость файла без раскрытия PlayerManager экранному flow.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает текущий файл через согласованное playback-состояние.
    private let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Выполняет существующий write-layer приложения.
    private let commandExecutor: any RenameTrackFileCommandExecuting
    /// Показывает существующие Toast-сообщения.
    private let toastPresenter: any ToastPresenting
    /// Закрывает Rename Track File sheet через typed-route.
    private let router: any RenameTrackFileRouting
    /// Формирует новое имя по существующей доменной логике.
    private let proposalBuilder: FileRenameProposalBuilder

    init(
        fileBusyChecker: any TrackFileBusyChecking,
        playbackFileReleaser: any CurrentPlaybackFileReleasing,
        commandExecutor: any RenameTrackFileCommandExecuting,
        toastPresenter: any ToastPresenting,
        router: any RenameTrackFileRouting,
        proposalBuilder: FileRenameProposalBuilder
    ) {
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.router = router
        self.proposalBuilder = proposalBuilder
    }

    /// Создаёт стабильный корневой контейнер sheet из неизменяемого route payload.
    func makeView(
        data: RenameTrackFileSheetData
    ) -> RenameTrackFileContainer {
        let presenter = RenameTrackFilePresenter(
            toastPresenter: toastPresenter
        )
        let actionHandler = RenameTrackFileActionHandler(
            fileBusyChecker: fileBusyChecker,
            playbackFileReleaser: playbackFileReleaser,
            commandExecutor: commandExecutor,
            proposalBuilder: proposalBuilder,
            presenter: presenter,
            router: router,
            routeID: data.id
        )
        let viewModel = RenameTrackFileViewModel(
            trackId: data.trackId,
            currentFileName: data.currentFileName,
            initialFileName: (data.currentFileName as NSString).deletingPathExtension,
            presenter: presenter,
            actionHandler: actionHandler
        )

        return RenameTrackFileContainer(viewModel: viewModel)
    }
}
