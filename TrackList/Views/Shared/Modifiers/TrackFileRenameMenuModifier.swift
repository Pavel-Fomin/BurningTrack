//
//  TrackFileRenameMenuModifier.swift
//  TrackList
//
//  Общий modifier меню переименования файла трека.
//
//  Роль:
//  - показывает одинаковое context menu для строк фонотеки, плеера и треклистов
//  - строит предложения переименования через FileRenameProposalBuilder
//  - открывает ручной rename sheet через SheetManager
//  - не знает о конкретной модели строки
//
//  Created by Pavel Fomin on 18.05.2026.
//

import SwiftUI

struct TrackFileRenameMenuModifier: ViewModifier {

    // MARK: - Input

    let trackId: UUID
    let rowId: UUID
    let currentFileName: String
    let artist: String?
    let title: String?
    let playerManager: PlayerManager
    let isEnabled: Bool

    @EnvironmentObject private var sheetManager: SheetManager

    // MARK: - Derived rename data

    /// Исполнитель без лишних пробелов для генерации имени файла.
    private var normalizedArtist: String {
        (artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Название без лишних пробелов для генерации имени файла.
    private var normalizedTitle: String {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Достаточно ли тегов для автоматического переименования.
    private var hasUsableTagsForRename: Bool {
        !normalizedArtist.isEmpty && !normalizedTitle.isEmpty
    }

    /// Предпросмотр имени в формате "исполнитель - название".
    private var artistTitlePreview: String {
        "\(normalizedArtist) - \(normalizedTitle)"
    }

    /// Предпросмотр имени в формате "название - исполнитель".
    private var titleArtistPreview: String {
        "\(normalizedTitle) - \(normalizedArtist)"
    }

    // MARK: - UI

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contextMenu {
                    Text("Изменить название файла")

                    if hasUsableTagsForRename {
                        Button("Артист - Название") {
                            renameUsingTags(strategy: .artistTitle)
                        }

                        Text(artistTitlePreview)
                            .disabled(true)

                        Divider()

                        Button("Название - Артист") {
                            renameUsingTags(strategy: .titleArtist)
                        }

                        Text(titleArtistPreview)
                            .disabled(true)
                    } else {
                        Button("Теги не заполнены") {}
                            .disabled(true)
                    }

                    Divider()

                    Button("Исправить вручную") {
                        sheetManager.presentRenameTrackFile(
                            trackId: trackId,
                            rowId: rowId,
                            currentFileName: currentFileName
                        )
                    }
                }
        } else {
            content
        }
    }

    // MARK: - Actions

    /// Переименовывает файл по тегам через общий генератор предложения.
    private func renameUsingTags(strategy: FileRenameStrategy) {
        let input = FileRenameInput(
            trackId: trackId,
            currentFileName: currentFileName,
            artist: artist,
            title: title
        )

        let proposal = FileRenameProposalBuilder().makeProposal(
            from: input,
            strategy: strategy
        )

        guard case .ready = proposal.status else {
            if case .skipped(let reason) = proposal.status {
                ToastManager.shared.handle(.operationFailed(message: reason))
            } else {
                ToastManager.shared.handle(
                    .operationFailed(message: "Не удалось подготовить новое имя файла")
                )
            }
            return
        }

        Task {
            do {
                try await AppCommandExecutor.shared.saveTrackEdits(
                    trackId: trackId,
                    newFileName: proposal.newFileName,
                    fileChanged: true,
                    patch: TagWritePatch(),
                    tagsChanged: false,
                    artworkAction: .none,
                    artworkChanged: false,
                    using: playerManager
                )
            } catch let appError as AppError {
                ToastManager.shared.handle(appError)
            } catch {
                ToastManager.shared.handle(
                    .operationFailed(message: "Не удалось переименовать файл")
                )
            }
        }
    }
}

extension View {

    /// Подключает единое меню переименования файла к строке трека.
    func trackFileRenameMenu(
        trackId: UUID,
        rowId: UUID,
        currentFileName: String,
        artist: String?,
        title: String?,
        playerManager: PlayerManager,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            TrackFileRenameMenuModifier(
                trackId: trackId,
                rowId: rowId,
                currentFileName: currentFileName,
                artist: artist,
                title: title,
                playerManager: playerManager,
                isEnabled: isEnabled
            )
        )
    }
}
