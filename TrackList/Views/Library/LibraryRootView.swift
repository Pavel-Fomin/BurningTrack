//
//  LibraryRootView.swift
//  TrackList
//
//  Контейнер корня фонотеки с переключением режимов.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

struct LibraryRootView: View {
    // MARK: - Входные данные

    /// Готовое состояние старого режима папок.
    let folderState: LibraryMasterScreenState
    /// Выбранный режим корня фонотеки, которым владеет контейнер с toolbar.
    let displayMode: LibraryRootDisplayMode
    /// Строки корневого списка режима "Треки" в явном порядке.
    let collectionRootItems: [LibraryCollectionRootItemState]
    /// Передаёт действия режима папок в существующий обработчик.
    let onFolderAction: (LibraryMasterAction) -> Void
    /// Передаёт выбор строки режима "Треки" в контейнер фонотеки.
    let onCollectionRootItemSelected: (LibraryCollectionRootItem) -> Void

    // MARK: - UI

    var body: some View {
        content
    }

    /// Показывает выбранный режим, не смешивая его логику с экраном папок.
    @ViewBuilder
    private var content: some View {
        switch displayMode {
        case .folders:
            MusicLibraryView(
                state: folderState,
                onAction: onFolderAction
            )

        case .tracks:
            LibraryTracksRootView(
                rootItems: collectionRootItems,
                onRootItemSelected: onCollectionRootItemSelected
            )
        }
    }
}
