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
            // Категории коллекции образуют самостоятельный компактный блок без заголовка секции.
            Section {
                LibraryTracksRootView(
                    rootItems: collectionRootItems,
                    onRootItemSelected: onCollectionRootItemSelected
                )
                // Сетка начинается у границ inset grouped-контейнера без второго внутреннего отступа строки.
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                )
                // Сетка сама рисует системные карточки, поэтому фон строки списка остаётся прозрачным.
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Folders") {
                // Виртуальный источник отображается первой строкой, но не входит в массив реальных папок.
                if folderState.showsPurchasedITunesSource {
                    purchasedITunesRow
                }

                // Секция папок остаётся самостоятельным компонентом и не смешивает свои строки с виртуальным источником.
                MusicLibraryView(
                    state: folderState,
                    onAction: onFolderAction
                )
            }
        }
        // Нативный inset grouped-стиль объединяет iTunes, реальные папки и добавление папки в одну секцию.
        .listStyle(.insetGrouped)
        .globalBottomScrollReserve()
    }

    /// Строит строку виртуального источника iTunes в секции папок отдельно от реальных папок.
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
