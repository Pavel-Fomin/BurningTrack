//
//  FolderContextMenu.swift
//  TrackList
//
//  Контекстное меню для вложенной папки внутри LibraryFolderView
//
//  Created by Pavel Fomin on 14.08.2025.
//

import SwiftUI

struct FolderContextMenu: ViewModifier {
    let folder: LibraryFolder
    let siblings: [LibraryFolder]
    @ObservedObject var viewModel: LibraryFolderViewModel
    @EnvironmentObject private var sheetManager: SheetManager

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                sheetManager.presentRename(url: folder.url) { newName in
                    _ = LibraryFileManager.shared.renameItem(at: folder.url, to: newName)
                    Task { await viewModel.refresh() }
                }
            } label: {
                Label("Переименовать", systemImage: "pencil")
            }

            Button {
                let destinations = siblings.map(\.url).filter { $0 != folder.url }
                sheetManager.presentMoveSheet(
                    sourceURL: folder.url,
                    availableFolders: destinations
                ) { destination in
                    let newURL = destination.appendingPathComponent(folder.url.lastPathComponent)
                    _ = LibraryFileManager.shared.moveItem(from: folder.url, to: newURL)
                    Task { await viewModel.refresh() }
                }
            } label: {
                Label("Переместить", systemImage: "arrow.right.arrow.left")
            }

            Button {
                // Пока неактуально
            } label: {
                Label("Открепить", systemImage: "pin.slash.fill")
            }

            Button(role: .destructive) {
                viewModel.pendingDeleteURL = folder.url
            } label: {
                Label("Удалить с iPhone", systemImage: "trash")
            }
        }
    }
}

extension View {
    func folderContextMenu(
        folder: LibraryFolder,
        siblings: [LibraryFolder],
        viewModel: LibraryFolderViewModel
    ) -> some View {
        self.modifier(FolderContextMenu(folder: folder, siblings: siblings, viewModel: viewModel))
    }
}
