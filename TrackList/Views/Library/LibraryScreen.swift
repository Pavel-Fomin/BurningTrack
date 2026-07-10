//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”.
//  Управляет только отображением содержимого фонотеки:
//  — корневые режимы папок и разделов коллекции,
//  — содержимое конкретной папки.
//
//  Навигация между вкладками → ScenePhaseHandler.
//  Маршруты внутри фонотеки → NavigationCoordinator.libraryRoute.
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI
import UIKit

struct SelectionActionBarConfig {
    /// Заголовок нижней панели.
    let title: String

    /// Подзаголовок нижней панели, например количество выбранных элементов.
    let subtitle: String?

    /// Текст основной кнопки подтверждения.
    let primaryTitle: String

    /// Опциональная системная иконка.
    let iconName: String?

    /// Доступность основной кнопки.
    let isPrimaryEnabled: Bool

    /// Callback подтверждения, переданный владельцем состояния выбора.
    let onPrimaryTap: () -> Void
}

struct LibraryScreen: View {

    // MARK: - Зависимости

    /// Фабрика production action handler для корневого flow фонотеки.
    private let actionHandlerFactory = LibraryMasterActionHandlerFactory()

    let playerViewModel: PlayerViewModel

    // MARK: - ViewModels

    /// ViewModel контейнера фонотеки.
    @StateObject private var viewModel: LibraryScreenViewModel
    /// ViewModel корневого экрана фонотеки.
    @StateObject private var masterViewModel: LibraryMasterViewModel

    // MARK: - State

    @State private var isShowingFolderPicker = false
    /// Текущий режим корня фонотеки, переключаемый кнопкой в leading toolbar.
    @State private var rootDisplayMode: LibraryRootDisplayMode = .folders
    /// Конфигурация верхней нижней панели для текущего экрана фонотеки.
    @State private var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Init

    init(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        self._viewModel = StateObject(
            wrappedValue: LibraryScreenViewModelFactory.make()
        )
        self._masterViewModel = StateObject(
            wrappedValue: LibraryMasterViewModelFactory.make()
        )
    }

    /// Обработчик действий корневого flow фонотеки.
    private var actionHandler: LibraryMasterActionHandler {
        actionHandlerFactory.make(
            playerViewModel: playerViewModel,
            output: masterViewModel,
            requestFolderPicker: {
                isShowingFolderPicker = true
            }
        )
    }

    /// Binding пути навигации, который отправляет изменения через action.
    private var libraryPathBinding: Binding<[NavigationCoordinator.LibraryRoute]> {
        Binding(
            get: { viewModel.screenState.libraryPath },
            set: { libraryPath in
                viewModel.handle(.libraryPathChanged(libraryPath))
            }
        )
    }

    // MARK: - UI

    var body: some View {
        NavigationStack(path: libraryPathBinding) {
            rootContent
                .navigationTitle("Фонотека")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationDestination(for: NavigationCoordinator.LibraryRoute.self) { route in
                    destination(
                        for: viewModel.screenState.destination(for: route)
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            rootDisplayMode = rootDisplayMode.toggled
                        } label: {
                            Image(systemName: rootDisplayMode.systemImage)
                        }
                        .accessibilityLabel(rootDisplayMode.title)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        LibraryToolbarMenuButton(
                            state: masterViewModel.screenState,
                            displayMode: rootDisplayMode,
                            onAction: { action in
                                actionHandler.handle(action)
                            }
                        )
                    }
                }
        }
        .bottomPanelsHost(
            playerViewModel: playerViewModel,
            showsTopPanel: selectionActionBarConfig != nil
        ) {
            if let config = selectionActionBarConfig {
                SelectionActionBar(
                    title: config.title,
                    subtitle: config.subtitle,
                    primaryTitle: config.primaryTitle,
                    iconName: config.iconName,
                    isPrimaryEnabled: config.isPrimaryEnabled,
                    onPrimaryTap: config.onPrimaryTap
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.handle(.appeared)
        }
        .onChange(of: rootDisplayMode) { _, newMode in
            // Перечитываем корень именно в момент перехода в режим "Треки".
            guard newMode == .tracks else { return }
            viewModel.refreshCollectionRootItems()
        }
        // Выбор папки
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    actionHandler.handle(.folderPicked(folderURL))
                } else {
                    actionHandler.handle(.folderPickFailed)
                }
            case .failure:
                actionHandler.handle(.folderPickFailed)
            }
        }
    }

    // MARK: - Root контент

    @ViewBuilder
    private var rootContent: some View {
        LibraryRootView(
            folderState: masterViewModel.screenState,
            displayMode: rootDisplayMode,
            collectionRootItems: viewModel.collectionRootItems,
            onFolderAction: { action in
                actionHandler.handle(action)
            },
            onCollectionRootItemSelected: { item in
                viewModel.handle(.collectionRootItemSelected(item))
            }
        )
        .onAppear {
            selectionActionBarConfig = nil
            if rootDisplayMode == .tracks {
                viewModel.refreshCollectionRootItems()
            }
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for destination: LibraryScreenDestinationState) -> some View {
        switch destination {

        case .root:
            rootContent
                .navigationTitle("Фонотека")

        case .purchasedITunes:
            PurchasedITunesMusicView(
                playerViewModel: playerViewModel
            )
                .onAppear {
                    selectionActionBarConfig = nil
                }

        case .allLibraryTracks:
            LibraryCollectionTracksView(
                source: .allLibraryTracks,
                playerViewModel: playerViewModel,
                selectionActionBarConfig: $selectionActionBarConfig
            )
                .onAppear {
                    selectionActionBarConfig = nil
                }

        case .collectionCategory(let category):
            LibraryCollectionValuesView(
                viewModel: LibraryCollectionValuesViewModel(category: category),
                playerViewModel: playerViewModel,
                onValueSelected: { value in
                    viewModel.handle(.collectionValueSelected(value))
                }
            )
                .onAppear {
                    selectionActionBarConfig = nil
                }

        case .collectionValue(let category, let value, let artistKey):
            LibraryCollectionTracksView(
                source: .collectionValue(
                    category: category,
                    rawValue: value,
                    artistKey: artistKey
                ),
                playerViewModel: playerViewModel,
                selectionActionBarConfig: $selectionActionBarConfig
            )
                .onAppear {
                    selectionActionBarConfig = nil
                }

        case .folder(let destination):
            LibraryFolderContainer(
                folder: destination.folder,
                revealRequest: destination.revealRequest,
                onRevealHandled: { requestId in
                    viewModel.handle(.revealHandled(requestId))
                },
                playerViewModel: playerViewModel,
                selectionActionBarConfig: $selectionActionBarConfig
            )

        case .missingFolder:
            Text("Папка не найдена")
                .navigationTitle("Ошибка")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.handle(.folderMissingAppeared)
                }
        }
    }
}

/// Нативная кнопка toolbar-меню с поддержкой subtitle у вложенного пункта UIMenu.
private struct LibraryToolbarMenuButton: UIViewRepresentable {
    /// Готовое состояние корневого экрана фонотеки.
    let state: LibraryMasterScreenState
    /// Текущий режим корня определяет набор доступных действий.
    let displayMode: LibraryRootDisplayMode
    /// Передаёт пользовательские действия обработчику экрана.
    let onAction: (LibraryMasterAction) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = "Действия фонотеки"
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
        let children: [UIMenuElement]

        switch displayMode {
        case .folders:
            children = [
                makeAddFolderAction(),
                makeSortMenu()
            ]
        case .tracks:
            children = [
                makeAddFolderAction()
            ]
        }

        let menu = UIMenu(
            children: children
        )

        // Разрешает системе показать title и subtitle для пункта "Сортировка" в режиме папок.
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
            children: LibraryFoldersSortMode.allCases.map { mode in
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

    /// Собирает пункт добавления новой папки.
    private func makeAddFolderAction() -> UIAction {
        UIAction(
            title: "Добавить папку",
            image: UIImage(systemName: "folder.fill.badge.plus")
        ) { _ in
            onAction(.addFolderTapped)
        }
    }
}
