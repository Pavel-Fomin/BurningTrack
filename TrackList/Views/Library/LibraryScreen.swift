//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”.
//  Управляет только отображением содержимого фонотеки:
//  — корневой список папок,
//  — содержимое конкретной папки.
//
//  Навигация между вкладками → ScenePhaseHandler.
//  Маршруты внутри фонотеки → NavigationCoordinator.libraryRoute.
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

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
                .libraryToolbar(title: "Фонотека")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationDestination(for: NavigationCoordinator.LibraryRoute.self) { route in
                    destination(
                        for: viewModel.screenState.destination(for: route)
                    )
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
        MusicLibraryView(
            state: masterViewModel.screenState,
            onAction: { action in
                actionHandler.handle(action)
            }
        )
        .onAppear {
            selectionActionBarConfig = nil
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for destination: LibraryScreenDestinationState) -> some View {
        switch destination {

        case .root:
            rootContent
                .libraryToolbar(title: "Фонотека")

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
                .libraryToolbar(title: "Ошибка")
                .onAppear {
                    viewModel.handle(.folderMissingAppeared)
                }
        }
    }
}
