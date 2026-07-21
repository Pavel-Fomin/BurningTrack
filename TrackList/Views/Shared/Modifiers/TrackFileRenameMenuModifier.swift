//
//  TrackFileRenameMenuModifier.swift
//  TrackList
//
//  Общий modifier меню переименования файла трека.
//
//  Роль:
//  - показывает одинаковое context menu для строк фонотеки, плеера и треклистов
//  - показывает предпросмотр имени файла для автоматических стратегий
//  - передаёт выбранную стратегию переименования через callback
//  - не знает о конкретной модели строки
//
//  Created by Pavel Fomin on 18.05.2026.
//

import SwiftUI

struct TrackFileRenameMenuModifier: ViewModifier {

    // MARK: - Input

    let artist: String?
    let title: String?
    let isEnabled: Bool
    let onRename: (FileRenameStrategy) -> Void

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
                    Text(FileRenamePresentationText.renameFileTitle)

                    if hasUsableTagsForRename {
                        Button(
                            FileRenamePresentationText.strategyTitle(
                                for: FileRenameStrategy.artistTitle
                            )
                        ) {
                            onRename(.artistTitle)
                        }

                        Text(artistTitlePreview)
                            .disabled(true)

                        Divider()

                        Button(
                            FileRenamePresentationText.strategyTitle(
                                for: FileRenameStrategy.titleArtist
                            )
                        ) {
                            onRename(.titleArtist)
                        }

                        Text(titleArtistPreview)
                            .disabled(true)
                    } else {
                        Button(FileRenamePresentationText.tagsAreMissingTitle) {}
                            .disabled(true)
                    }

                    Divider()

                    Button(FileRenamePresentationText.editManuallyTitle) {
                        onRename(.manual)
                    }
                }
        } else {
            content
        }
    }
}

extension View {

    /// Подключает единое меню переименования файла к строке трека.
    func trackFileRenameMenu(
        artist: String?,
        title: String?,
        isEnabled: Bool = true,
        onRename: @escaping (FileRenameStrategy) -> Void
    ) -> some View {
        modifier(
            TrackFileRenameMenuModifier(
                artist: artist,
                title: title,
                isEnabled: isEnabled,
                onRename: onRename
            )
        )
    }
}
