//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”.
//  Управляет только отображением содержимого фонотеки:
//  — единый корень с папками и разделами коллекции,
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
    /// Фабрика обработчика экспорта общего списка треков.
    private let allTracksActionHandlerFactory = LibraryAllTracksActionHandlerFactory()
    /// Фабрика обработчика экспорта выбранного значения коллекции.
    private let collectionTracksActionHandlerFactory = LibraryCollectionTracksActionHandlerFactory()

    let playerViewModel: PlayerViewModel
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel

    // MARK: - ViewModels

    /// ViewModel контейнера фонотеки.
    @StateObject private var viewModel: LibraryScreenViewModel
    /// ViewModel корневого экрана фонотеки.
    @StateObject private var masterViewModel: LibraryMasterViewModel

    // MARK: - State

    @State private var isShowingFolderPicker = false
    /// Конфигурация верхней нижней панели для текущего экрана фонотеки.
    @State private var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Init

    init(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel
    ) {
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
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

    /// Обработчик действий экрана всех треков фонотеки.
    private var allTracksActionHandler: LibraryAllTracksActionHandler {
        allTracksActionHandlerFactory.make(
            exportProgressViewModel: exportProgressViewModel
        )
    }

    /// Собирает обработчик экспорта текущего выбранного значения коллекции.
    private func collectionTracksActionHandler(
        for source: LibraryTrackListSource
    ) -> LibraryCollectionTracksActionHandler {
        collectionTracksActionHandlerFactory.make(
            source: source,
            exportProgressViewModel: exportProgressViewModel
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
                .navigationTitle("Library")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationDestination(for: NavigationCoordinator.LibraryRoute.self) { route in
                    destination(
                        for: viewModel.screenState.destination(for: route)
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        LibraryToolbarMenuButton(
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
            // Коллекция всегда видна в едином корне, поэтому её счётчики загружаются при появлении.
            viewModel.setCollectionRootVisibility(true)
        }
        .onDisappear {
            viewModel.setCollectionRootVisibility(false)
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for destination: LibraryScreenDestinationState) -> some View {
        switch destination {

        case .root:
            rootContent
                .navigationTitle("Library")

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
                selectionActionBarConfig: $selectionActionBarConfig,
                onAllTracksAction: { action in
                    allTracksActionHandler.handle(action)
                }
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
                selectionActionBarConfig: $selectionActionBarConfig,
                onCollectionTracksAction: { action in
                    collectionTracksActionHandler(
                        for: .collectionValue(
                            category: category,
                            rawValue: value,
                            artistKey: artistKey
                        )
                    )
                    .handle(action)
                }
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
                exportProgressViewModel: exportProgressViewModel,
                selectionActionBarConfig: $selectionActionBarConfig
            )

        case .missingFolder:
            Text("Folder Not Found")
                .navigationTitle("Error")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.handle(.folderMissingAppeared)
                }
        }
    }
}

/// Нативная кнопка toolbar-меню корневого экрана фонотеки.
private struct LibraryToolbarMenuButton: UIViewRepresentable {
    /// Передаёт пользовательские действия обработчику экрана.
    let onAction: (LibraryMasterAction) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = String(localized: "Library Actions")
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.menu = makeMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = makeMenu()
    }

    /// Собирает системное меню доступных действий с корневыми папками.
    private func makeMenu() -> UIMenu {
        UIMenu(
            children: [makeAddFolderAction()]
        )
    }

    /// Собирает пункт добавления новой папки.
    private func makeAddFolderAction() -> UIAction {
        UIAction(
            title: String(localized: "Add Folder"),
            image: UIImage(systemName: "folder.fill.badge.plus")
        ) { _ in
            onAction(.addFolderTapped)
        }
    }
}
