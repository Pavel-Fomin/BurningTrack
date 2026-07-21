//
//  TrackFileRenameActionHandler.swift
//  TrackList
//
//  Общий обработчик сценария переименования файла трека.
//
//  Created by Pavel Fomin on 14.06.2026.
//

import Foundation

/// Запрос на переименование файла трека.
struct TrackFileRenameRequest {

    /// Идентификатор физического трека.
    let trackId: UUID

    /// Идентификатор строки, связанной с текущим rename-flow.
    let rowId: UUID

    /// Актуальное имя файла.
    let currentFileName: String

    /// Исполнитель из runtime metadata.
    let artist: String?

    /// Название трека из runtime metadata.
    let title: String?

    /// Выбранная стратегия переименования.
    let strategy: FileRenameStrategy
}

/// Выполняет сценарий переименования файла трека.
///
/// Handler не зависит от конкретного экрана.
/// Он получает готовый контекст rename-flow и выполняет:
/// - открытие ручного sheet;
/// - автоматическое переименование;
/// - обработку ошибок.
@MainActor
final class TrackFileRenameActionHandler {

    // MARK: - Dependencies

    private let playerManager: PlayerManager
    private let sheetManager: SheetManager
    private let commandExecutor: AppCommandExecutor
    private let toastManager: ToastManager
    private let proposalBuilder: FileRenameProposalBuilder

    // MARK: - Инициализация

    init(
        playerManager: PlayerManager,
        sheetManager: SheetManager,
        commandExecutor: AppCommandExecutor,
        toastManager: ToastManager,
        proposalBuilder: FileRenameProposalBuilder
    ) {
        self.playerManager = playerManager
        self.sheetManager = sheetManager
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager
        self.proposalBuilder = proposalBuilder
    }

    // MARK: - Public API

    /// Обрабатывает запрос на переименование файла трека.
    func handle(_ request: TrackFileRenameRequest) {
        if request.strategy == .manual {
            sheetManager.presentRenameTrackFile(
                trackId: request.trackId,
                rowId: request.rowId,
                currentFileName: request.currentFileName
            )
            return
        }

        let input = FileRenameInput(
            trackId: request.trackId,
            currentFileName: request.currentFileName,
            artist: request.artist,
            title: request.title
        )

        let proposal = proposalBuilder.makeProposal(
            from: input,
            strategy: request.strategy
        )

        guard case .ready = proposal.status else {
            if case .skipped(let reason) = proposal.status {
                toastManager.handle(
                    .operationFailed(
                        message: FileRenamePresentationText.skippedMessage(for: reason)
                    )
                )
            } else {
                toastManager.handle(
                    .operationFailed(
                        message: FileRenamePresentationText.preparationFailedMessage
                    )
                )
            }
            return
        }

        Task {
            do {
                try await commandExecutor.saveTrackEdits(
                    trackId: request.trackId,
                    newFileName: proposal.newFileName,
                    fileChanged: true,
                    patch: TagWritePatch(),
                    tagsChanged: false,
                    artworkAction: .none,
                    artworkChanged: false,
                    using: playerManager
                )
            } catch let appError as AppError {
                toastManager.handle(appError)
            } catch {
                toastManager.handle(
                    .operationFailed(
                        message: FileRenamePresentationText.fileRenameFailedMessage
                    )
                )
            }
        }
    }

}
