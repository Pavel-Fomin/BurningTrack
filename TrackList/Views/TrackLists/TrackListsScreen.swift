//
//  TrackListsScreen.swift
//  TrackList
//
//  Раздел "Треклисты".
//  NavigationStack держит переход от списка треклистов к detail-экрану
//  и обеспечивает корректную работу тулбара внутри вкладки.
//
//  Created by Pavel Fomin on 17.07.2025.
//

import SwiftUI
import UIKit

struct TrackListsScreen: View {

    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    /// Фабрика production action handler для master-flow списка треклистов.
    private let actionHandlerFactory = TrackListsActionHandlerFactory()

    /// Обрабатывает действия экрана списка треклистов.
    private var actionHandler: TrackListsActionHandler {
        actionHandlerFactory.make(
            viewModel: trackListsViewModel
        )
    }

    var body: some View {
        NavigationStack(path: $trackListsViewModel.navigationPath) {
            TrackListsListView(
                state: trackListsViewModel.screenState,
                onAction: { action in
                    actionHandler.handle(action)
                }
            )
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Треклисты")
            .navigationDestination(for: UUID.self) { id in
                // Detail-экран строится по route id, чтобы строка списка оставалась обычной Button-строкой без шеврона.
                if let trackList = trackListsViewModel.trackList(for: id) {
                    TrackListScreen(
                        trackList: trackList,
                        playerViewModel: playerViewModel
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TrackListsToolbarMenuButton(
                        state: trackListsViewModel.screenState,
                        onAction: { action in
                            actionHandler.handle(action)
                        }
                    )
                }
            }
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel
        )
    }
}

/// Нативная кнопка toolbar-меню с поддержкой subtitle у вложенного пункта UIMenu.
private struct TrackListsToolbarMenuButton: UIViewRepresentable {
    /// Готовое состояние экрана списка треклистов.
    let state: TrackListsScreenState
    /// Передаёт пользовательские действия обработчику экрана.
    let onAction: (TrackListsAction) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = "Действия треклистов"
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.menu = makeMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = makeMenu()
    }

    /// Собирает системное меню, где subtitle и checkmark рисуются UIKit.
    private func makeMenu() -> UIMenu {
        let menu = UIMenu(
            children: [
                makeCreateTrackListAction(),
                makeSortMenu()
            ]
        )

        // Разрешает системе показать title и subtitle для пункта "Сортировка".
        let displayPreferences = UIMenuDisplayPreferences()
        displayPreferences.maximumNumberOfTitleLines = 2
        menu.displayPreferences = displayPreferences

        return menu
    }

    /// Собирает вложенное меню сортировки с системной подписью выбранного режима.
    private func makeSortMenu() -> UIMenu {
        let menu = UIMenu(
            title: "Сортировка",
            image: UIImage(systemName: "arrow.up.arrow.down"),
            options: .singleSelection,
            children: TrackListsSortMode.allCases.map { mode in
                UIAction(
                    title: mode.title,
                    state: state.selectedSortMode == mode ? .on : .off
                ) { _ in
                    onAction(.setSortMode(mode))
                }
            }
        )
        menu.subtitle = state.sortModeCaption
        return menu
    }

    /// Собирает пункт создания нового треклиста.
    private func makeCreateTrackListAction() -> UIAction {
        UIAction(
            title: "Новый треклист",
            image: UIImage(systemName: "text.badge.plus")
        ) { _ in
            onAction(.createTrackList)
        }
    }
}
