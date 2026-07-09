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
    /// Разделы музыкальной коллекции для режима "Треки".
    let collectionCategories: [LibraryCollectionCategory]
    /// ViewModel плеера нужна только режиму "Треки" для строк общего списка.
    @ObservedObject var playerViewModel: PlayerViewModel
    /// Конфигурация нижней панели массового выбора в общем host фонотеки.
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    /// Передаёт действия режима папок в существующий обработчик.
    let onFolderAction: (LibraryMasterAction) -> Void
    /// Передаёт выбор раздела коллекции в контейнер фонотеки.
    let onCollectionCategorySelected: (LibraryCollectionCategory) -> Void

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
                categories: collectionCategories,
                playerViewModel: playerViewModel,
                selectionActionBarConfig: $selectionActionBarConfig,
                onCategorySelected: onCollectionCategorySelected
            )
        }
    }
}
