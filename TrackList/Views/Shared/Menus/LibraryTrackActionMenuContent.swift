//
//  LibraryTrackActionMenuContent.swift
//  TrackList
//
//  Меню действий строки фонотеки.
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

/// Единый состав ellipsis-меню для одиночного трека фонотеки.
struct LibraryTrackActionMenuContent: View {
    let onDetails: () -> Void
    let onMoveToFolder: () -> Void
    let onAddToPlayer: () -> Void
    let onAddToTrackList: () -> Void
    let onEditTags: () -> Void
    let onRenameFile: (FileRenameStrategy) -> Void

    var body: some View {
        if isMenuActionAvailable(.details) {
            Button {
                onDetails()
            } label: {
                Label("О треке", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            Button {
                onMoveToFolder()
            } label: {
                Label("Переместить", systemImage: "arrow.forward.folder")
            }
        }

        if isMenuActionAvailable(.addToPlayer) {
            Button {
                onAddToPlayer()
            } label: {
                Label("В плеер", systemImage: "waveform")
            }
        }

        if isMenuActionAvailable(.addToTrackList) {
            Button {
                onAddToTrackList()
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
        }

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags()
                    } label: {
                        Label("Теги", systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section("Название файла") {
                        Button {
                            onRenameFile(.artistTitle)
                        } label: {
                            Text("Артист - Название")
                        }

                        Button {
                            onRenameFile(.titleArtist)
                        } label: {
                            Text("Название - Артист")
                        }

                        Button {
                            onRenameFile(.manual)
                        } label: {
                            Text("Вручную")
                        }
                    }
                }
            } label: {
                Label("Редактировать", systemImage: "square.and.pencil")
            }
        }
    }

    /// Доступность пунктов берётся из каноничных правил фонотеки.
    private func isMenuActionAvailable(_ action: TrackMenuAction) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: .library,
            context: .library
        )
    }
}
