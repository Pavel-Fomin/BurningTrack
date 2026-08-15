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

    /// Текст основной кнопки подтверждения; отсутствует в обычном режиме выбора.
    let primaryTitle: String?

    /// Опциональная системная иконка.
    let iconName: String?

    /// Доступность основной кнопки.
    let isPrimaryEnabled: Bool

}

struct LibraryScreen: View {

    // MARK: - Зависимости

    /// Единый обработчик «Избранного» передаётся в строки всех источников фонотеки.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовые фабрики feature фонотеки, подготовленные Composition Root.
    let dependencies: LibraryFeatureDependencies

    // MARK: - Screen state

    /// Store удерживает root graph, созданный контейнером вне SwiftUI View.
    private let screenStore: LibraryScreenStore
    /// ViewModel контейнера фонотеки.
    @ObservedObject private var viewModel: LibraryScreenViewModel
    /// ViewModel корневого экрана фонотеки.
    @ObservedObject private var masterViewModel: LibraryMasterViewModel

    // MARK: - Состояние

    @State private var isShowingFolderPicker = false
    /// Конфигурация верхней нижней панели для текущего экрана фонотеки.
    @State private var selectionActionBarConfig: SelectionActionBarConfig?
    /// Маршрут подтверждения принадлежит дочернему экрану, а host хранит только ссылку для возврата действия.
    @State private var selectionActionSender: (any LibraryTracksActionSending)?

    // MARK: - Инициализация

    init(
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        dependencies: LibraryFeatureDependencies,
        screenStore: LibraryScreenStore
    ) {
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.dependencies = dependencies
        self.screenStore = screenStore
        self._viewModel = ObservedObject(wrappedValue: screenStore.viewModel)
        self._masterViewModel = ObservedObject(wrappedValue: screenStore.masterViewModel)
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

    // MARK: - Интерфейс

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
                                screenStore.masterActionHandler.handle(action)
                            }
                        )
                    }
                }
        }
        .onChange(of: viewModel.screenState.libraryPath) { oldPath, newPath in
            handleLibraryPathChange(from: oldPath, to: newPath)
        }
        .bottomPanelsHost(
            showsTopPanel: selectionActionBarConfig != nil
        ) {
            if let config = selectionActionBarConfig {
                SelectionActionBar(
                    title: config.title,
                    subtitle: config.subtitle,
                    primaryTitle: config.primaryTitle,
                    iconName: config.iconName,
                    isPrimaryEnabled: config.isPrimaryEnabled,
                    onPrimaryTap: {
                        selectionActionSender?.send(.batchActionConfirmed)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.handle(.appeared)
        }
        .onChange(of: masterViewModel.screenState.folderPickerRequestID) { _, requestID in
            guard requestID != nil else { return }
            isShowingFolderPicker = true
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
                    screenStore.masterActionHandler.handle(.folderPicked(folderURL))
                } else {
                    screenStore.masterActionHandler.handle(.folderPickFailed)
                }
            case .failure:
                screenStore.masterActionHandler.handle(.folderPickFailed)
            }
        }
    }

    // MARK: - Корневое содержимое

    @ViewBuilder
    private var rootContent: some View {
        LibraryRootView(
            folderState: masterViewModel.screenState,
            collectionRootItems: viewModel.collectionRootItems,
            onFolderAction: { action in
                screenStore.masterActionHandler.handle(action)
            },
            onCollectionRootItemSelected: { item in
                viewModel.handle(.collectionRootItemSelected(item))
            }
        )
        .onAppear {
            // Коллекция всегда видна в едином корне, поэтому её счётчики загружаются при появлении.
            viewModel.handle(.collectionRootAppeared)
        }
        .onDisappear {
            viewModel.handle(.collectionRootDisappeared)
        }
    }

    // MARK: - Навигационные назначения

    @ViewBuilder
    private func destination(for destination: LibraryScreenDestinationState) -> some View {
        switch destination {

        case .root:
            rootContent
                .navigationTitle("Library")

        case .purchasedITunes(let revealRequest):
            dependencies.purchasedITunesFeatureFactory.makeContainer(
                revealRequest: revealRequest,
                onRevealHandled: { requestId in
                    viewModel.handle(.revealHandled(requestId))
                }
            )

        case .allLibraryTracks:
            dependencies.tracksScreenFactory.makeLibraryCollectionTracksContainer(
                source: .allLibraryTracks,
                selectionActionBarConfig: $selectionActionBarConfig,
                selectionActionSender: $selectionActionSender
            )
            .id(LibraryTrackListSource.allLibraryTracks.id)

        case .collectionCategory(let category):
            dependencies.collectionValuesFeatureFactory.makeContainer(
                category: category,
                onValueSelected: { value in
                    viewModel.handle(.collectionValueSelected(value))
                }
            )

        case .collectionValue(let category, let value, let artistKey):
            collectionTracksDestination(
                source: .collectionValue(
                    category: category,
                    rawValue: value,
                    artistKey: artistKey
                )
            )

        case .folder(let destination):
            LibraryFolderContainer(
                folder: destination.folder,
                revealRequest: destination.revealRequest,
                onRevealHandled: { requestId in
                    viewModel.handle(.revealHandled(requestId))
                },
                viewModelFactory: dependencies.folderViewModelFactory,
                tracksScreenFactory: dependencies.tracksScreenFactory,
                selectionActionBarConfig: $selectionActionBarConfig,
                selectionActionSender: $selectionActionSender
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

    /// Создаёт destination выбранного значения коллекции с graph, связанным со стабильной identity источника.
    private func collectionTracksDestination(
        source: LibraryTrackListSource
    ) -> some View {
        dependencies.tracksScreenFactory.makeLibraryCollectionTracksContainer(
            source: source,
            selectionActionBarConfig: $selectionActionBarConfig,
            selectionActionSender: $selectionActionSender
        )
        .id(source.id)
    }

    /// Завершает selection только когда активная папка перестала быть текущим destination.
    private func handleLibraryPathChange(
        from oldPath: [NavigationCoordinator.LibraryRoute],
        to newPath: [NavigationCoordinator.LibraryRoute]
    ) {
        guard LibraryFolderRouteClosureEvaluator.didCloseActiveFolder(
            from: oldPath,
            to: newPath
        ) else {
            return
        }

        selectionActionSender?.send(.screenClosed)
        selectionActionSender = nil
        selectionActionBarConfig = nil
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
