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
    /// Единый обработчик «Избранного» передаётся в detail-flow треклистов.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Единый ActionHandler master-flow, подготовленный Composition Root.
    let actionHandler: TrackListsActionHandler
    /// Единый координатор навигации, подготовленный Composition Root.
    @ObservedObject var navigationCoordinator: NavigationCoordinator
    /// Готовые фабрики detail-flow одного треклиста.
    let trackListFeatureDependencies: TrackListFeatureDependencies

    var body: some View {
        NavigationStack(path: $trackListsViewModel.navigationPath) {
            TrackListsListView(
                state: trackListsViewModel.screenState,
                onAction: { action in
                    actionHandler.handle(action)
                }
            )
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tracklists")
            .navigationDestination(for: UUID.self) { id in
                // Detail-экран строится по route id, чтобы строка списка оставалась обычной Button-строкой без шеврона.
                if trackListsViewModel.trackList(for: id) != nil {
                    TrackListScreen(
                        trackListId: id,
                        favoriteTrackActionHandler: favoriteTrackActionHandler,
                        dependencies: trackListFeatureDependencies
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
        .onAppear {
            actionHandler.handlePendingExternalOpenRequest()
        }
        .onChange(of: navigationCoordinator.pendingTrackListOpenRequest) { _, _ in
            actionHandler.handlePendingExternalOpenRequest()
        }
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
        button.accessibilityLabel = String(localized: "Tracklist Actions")
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
            title: String(localized: "Sort"),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            options: .singleSelection,
            children: TrackListsSortMode.allCases.map { mode in
                UIAction(
                    title: TrackListPresentationText.sortTitle(for: mode),
                    state: state.selectedSortMode == mode ? .on : .off
                ) { _ in
                    onAction(.setSortMode(mode))
                }
            }
        )
        menu.subtitle = state.selectedSortMode.map(
            TrackListPresentationText.sortCaption(for:)
        )
        return menu
    }

    /// Собирает пункт создания нового треклиста.
    private func makeCreateTrackListAction() -> UIAction {
        UIAction(
            title: String(localized: "Create Tracklist"),
            image: UIImage(systemName: "text.badge.plus")
        ) { _ in
            onAction(.createTrackList)
        }
    }
}
