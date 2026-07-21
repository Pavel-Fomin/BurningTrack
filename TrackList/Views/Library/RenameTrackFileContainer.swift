//
//  RenameTrackFileContainer.swift
//  TrackList
//
//  Контейнер ручного переименования файла трека.
//  Готовит предложение переименования и отправляет команду сохранения без прямой работы с файловой системой.
//
//  Created by Pavel Fomin on 17.05.2026.
//

import SwiftUI

struct RenameTrackFileContainer: View {

    // MARK: - Input

    let data: RenameTrackFileSheetData
    let playerManager: PlayerManager

    // MARK: - State

    @State private var fileName: String
    @State private var showStopPlayerAlert = false
    @State private var showFileNameConflictAlert = false
    @FocusState private var isFileNameFocused: Bool

    /// Проверяет, заполнено ли имя файла после удаления пробелов по краям.
    private var isFileNameValid: Bool {
        !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        data: RenameTrackFileSheetData,
        playerManager: PlayerManager
    ) {
        self.data = data
        self.playerManager = playerManager
        self._fileName = State(
            initialValue: (data.currentFileName as NSString).deletingPathExtension
        )
    }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: FileRenamePresentationText.renameFileTitle,
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(isFileNameValid),
            onClose: {
                closeSheet()
            },
            closeAccessibilityLabel: String(localized: "Cancel"),
            onRightTap: {
                Task { await rename() }
            },
            rightButtonAccessibilityLabel: String(localized: "Rename")
        ) {
            RenameTrackFileSheet(
                fileName: $fileName,
                isFileNameFocused: $isFileNameFocused
            )
        }
        .alert(
            FileRenamePresentationText.stopPlaybackTitle,
            isPresented: $showStopPlayerAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {}

            Button(FileRenamePresentationText.stopAndRenameTitle) {
                playerManager.pause()
                playerManager.stopAccessingCurrentTrack()
                Task { await rename() }
            }
        } message: {
            Text(FileRenamePresentationText.stopPlaybackDescription)
        }
        .alert(
            FileRenamePresentationText.nameConflictTitle,
            isPresented: $showFileNameConflictAlert
        ) {
            Button(String(localized: "Close"), role: .cancel) {}
        } message: {
            Text(FileRenamePresentationText.nameConflictDescription)
        }
    }

    // MARK: - Actions

    /// Закрывает sheet после предварительного снятия фокуса с поля ввода.
    private func closeSheet() {
        isFileNameFocused = false
        SheetManager.shared.closeActive()
    }

    /// Выполняет ручное переименование через общий генератор предложения и командный слой.
    private func rename() async {
        let input = FileRenameInput(
            trackId: data.trackId,
            currentFileName: data.currentFileName,
            artist: nil,
            title: nil
        )

        let proposal = FileRenameProposalBuilder().makeProposal(
            from: input,
            strategy: .manual,
            manualName: fileName
        )

        guard case .ready = proposal.status else {
            ToastManager.shared.handle(
                .operationFailed(
                    message: FileRenamePresentationText.preparationFailedMessage
                )
            )
            return
        }

        do {
            try await AppCommandExecutor.shared.saveTrackEdits(
                trackId: data.trackId,
                newFileName: proposal.newFileName,
                fileChanged: true,
                patch: TagWritePatch(),
                tagsChanged: false,
                artworkAction: .none,
                artworkChanged: false,
                using: playerManager
            )

            await MainActor.run {
                closeSheet()
            }
        } catch let appError as AppError {
            await MainActor.run {
                switch appError {
                case .fileAccessDenied:
                    showStopPlayerAlert = true
                case .fileAlreadyExists:
                    showFileNameConflictAlert = true
                default:
                    ToastManager.shared.handle(appError)
                }
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.handle(
                    .operationFailed(
                        message: FileRenamePresentationText.fileRenameFailedMessage
                    )
                )
            }
        }
    }
}
