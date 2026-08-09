//
//  RenameTrackFileActionHandler.swift
//  TrackList
//
//  Выполняет сценарий ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Выполняет ручную команду переименования без зависимости от SwiftUI-экрана.
@MainActor
final class RenameTrackFileActionHandler {

    /// Проверяет, удерживает ли плеер доступ к переименовываемому файлу.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает текущий файл только после подтверждения пользователя.
    private let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Выполняет существующую команду сохранения изменений трека.
    private let commandExecutor: any RenameTrackFileCommandExecuting
    /// Сохраняет существующую доменную логику формирования нового имени.
    private let proposalBuilder: FileRenameProposalBuilder
    /// Преобразует результаты команды в presentation-результат flow.
    private let presenter: RenameTrackFilePresenter
    /// Закрывает flow через узкий typed-route.
    private let router: any RenameTrackFileRouting
    /// Неизменяемая идентичность конкретного Rename Track File route.
    private let routeID: UUID

    /// Последняя команда, которая требует освобождения файла плеером перед повтором.
    private var pendingCommand: RenameTrackFileCommand?

    init(
        fileBusyChecker: any TrackFileBusyChecking,
        playbackFileReleaser: any CurrentPlaybackFileReleasing,
        commandExecutor: any RenameTrackFileCommandExecuting,
        proposalBuilder: FileRenameProposalBuilder,
        presenter: RenameTrackFilePresenter,
        router: any RenameTrackFileRouting,
        routeID: UUID = UUID()
    ) {
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.commandExecutor = commandExecutor
        self.proposalBuilder = proposalBuilder
        self.presenter = presenter
        self.router = router
        self.routeID = routeID
    }

    /// Закрывает sheet без запуска доменной команды.
    func close() {
        router.dismissRenameTrackFile(routeID)
    }

    /// Подготавливает ручное имя и выполняет прежнюю команду saveTrackEdits.
    func rename(
        trackId: UUID,
        currentFileName: String,
        manualFileName: String
    ) async -> RenameTrackFilePresentation {
        let command = RenameTrackFileCommand(
            trackId: trackId,
            currentFileName: currentFileName,
            manualFileName: manualFileName
        )
        return await execute(command)
    }

    /// Освобождает файл после подтверждения alert и повторяет только ожидающую команду.
    func confirmStopPlayback() async -> RenameTrackFilePresentation {
        guard let pendingCommand else {
            return .keepOpen(alert: nil)
        }

        playbackFileReleaser.releaseCurrentPlaybackFile()
        return await execute(pendingCommand)
    }

    /// Выполняет общий путь подготовки proposal и сохранения имени файла.
    private func execute(
        _ command: RenameTrackFileCommand
    ) async -> RenameTrackFilePresentation {
        let input = FileRenameInput(
            trackId: command.trackId,
            currentFileName: command.currentFileName,
            artist: nil,
            title: nil
        )
        let proposal = proposalBuilder.makeProposal(
            from: input,
            strategy: .manual,
            manualName: command.manualFileName
        )

        guard case .ready = proposal.status else {
            pendingCommand = nil
            return presenter.presentPreparationFailure()
        }

        do {
            let result = try await commandExecutor.saveTrackEdits(
                trackId: command.trackId,
                newFileName: proposal.newFileName,
                fileChanged: true,
                patch: TagWritePatch(),
                tagsChanged: false,
                artworkAction: .none,
                artworkChanged: false,
                using: fileBusyChecker
            )
            pendingCommand = nil
            return finish(presenter.present(result))
        } catch let appError as AppError {
            if case .fileAccessDenied = appError {
                pendingCommand = command
            } else {
                pendingCommand = nil
            }
            return finish(presenter.present(appError))
        } catch {
            pendingCommand = nil
            return finish(presenter.presentUnknownFailure())
        }
    }

    /// Выполняет typed-route только для успешного завершения операции.
    private func finish(
        _ presentation: RenameTrackFilePresentation
    ) -> RenameTrackFilePresentation {
        if case .close = presentation {
            router.dismissRenameTrackFile(routeID)
        }
        return presentation
    }
}

/// Неизменяемые входные данные одной попытки ручного переименования.
private struct RenameTrackFileCommand {
    /// Идентификатор физического трека.
    let trackId: UUID
    /// Имя файла до переименования, необходимое для сохранения расширения.
    let currentFileName: String
    /// Введённая пользователем основа нового имени файла.
    let manualFileName: String
}
