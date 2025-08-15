//
//  RootFolderContextMenu.swift
//  TrackList
//
//  Контекстное меню для корневой папки фонотеки
//
//  Created by Pavel Fomin on 14.08.2025.
//

import SwiftUI

struct RootFolderContextMenu: ViewModifier {
    let folder: LibraryFolder
    let manager: MusicLibraryManager
    @EnvironmentObject private var sheetManager: SheetManager

    @ViewBuilder
    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                sheetManager.presentRenameFolder(for: folder.url) { newName in
                    Task {
                        let result = LibraryFileManager.shared.renameItem(at: folder.url, to: newName)
                        if case .success(let newURL) = result {
                            manager.moveBookmark(from: folder.url, to: newURL)
                            await manager.restoreAccess()
                        }
                    }
                }
            } label: {
                Label("Переименовать", systemImage: "pencil")
            }

            Button {
                // Пока перемещение отключено
            } label: {
                Label("Переместить", systemImage: "arrow.right.arrow.left")
            }

            Button {
                manager.removeBookmark(for: folder.url)
            } label: {
                Label("Открепить", systemImage: "pin.slash.fill")
            }

            Button(role: .destructive) {
                manager.pendingDeleteURL = folder.url
            } label: {
                Label("Удалить с iPhone", systemImage: "trash")
            }
        }
    }
}


extension View {
    func rootFolderContextMenu(for folder: LibraryFolder, manager: MusicLibraryManager) -> some View {
        self.modifier(RootFolderContextMenu(folder: folder, manager: manager))
    }
}
