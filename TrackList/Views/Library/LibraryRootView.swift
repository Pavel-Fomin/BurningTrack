//
//  LibraryRootView.swift
//  TrackList
//
//  Единый корневой экран фонотеки.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import SwiftUI

struct LibraryRootView: View {
    // MARK: - Входные данные

    /// Готовое состояние секции прикреплённых папок.
    let folderState: LibraryMasterScreenState
    /// Строки секции коллекции в явном порядке.
    let collectionRootItems: [LibraryCollectionRootItemState]
    /// Передаёт действия секции папок и системных источников в существующий обработчик.
    let onFolderAction: (LibraryMasterAction) -> Void
    /// Передаёт выбор строки коллекции в контейнер фонотеки.
    let onCollectionRootItemSelected: (LibraryCollectionRootItem) -> Void

    // MARK: - UI

    var body: some View {
        List {
            Section("Collection") {
                LibraryTracksRootView(
                    rootItems: collectionRootItems,
                    onRootItemSelected: onCollectionRootItemSelected
                )

                if folderState.showsPurchasedITunesSource {
                    purchasedITunesRow
                }
            }

            Section("Folders") {
                // Секция папок остаётся самостоятельным компонентом и не смешивает свои строки с коллекцией.
                MusicLibraryView(
                    state: folderState,
                    onAction: onFolderAction
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Строит строку виртуального источника iTunes в секции коллекции отдельно от реальных папок.
    private var purchasedITunesRow: some View {
        Button {
            onFolderAction(.openPurchasedITunes)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text("Purchased in iTunes")
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
