//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”.
//  Управляет только отображением содержимого фонотеки:
//  — корневой список папок,
//  — содержимое конкретной папки,
//  — обработка события "показать трек во фонотеке".
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

    private let musicLibraryManager = MusicLibraryManager.shared
    /// Фабрика production action handler для корневого flow фонотеки.
    private let actionHandlerFactory = LibraryMasterActionHandlerFactory()

    let playerViewModel: PlayerViewModel
    
    @ObservedObject private var nav = NavigationCoordinator.shared
    /// ViewModel корневого экрана фонотеки.
    @StateObject private var masterViewModel = LibraryMasterViewModel()

    @State private var isShowingFolderPicker = false
    /// Конфигурация верхней нижней панели для текущего экрана фонотеки.
    @State private var selectionActionBarConfig: SelectionActionBarConfig?

    /// Обработчик действий корневого flow фонотеки.
    private var actionHandler: LibraryMasterActionHandler {
        actionHandlerFactory.make(
            playerViewModel: playerViewModel,
            viewModel: masterViewModel,
            requestFolderPicker: {
                isShowingFolderPicker = true
            }
        )
    }

    // MARK: - UI

    var body: some View {
        NavigationStack(path: $nav.libraryPath) {
            rootContent
                .libraryToolbar(title: "Фонотека")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationDestination(for: NavigationCoordinator.LibraryRoute.self) { route in
                    destination(for: route)
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
            handlePendingShowTrack()
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
    private func destination(for route: NavigationCoordinator.LibraryRoute) -> some View {
        switch route {

        case .root:
            rootContent
                .libraryToolbar(title: "Фонотека")

        case .folder(let folderId):
            if let folder = musicLibraryManager.folder(for: folderId) {
                LibraryFolderContainer(
                    folder: folder,
                    revealRequest: revealRequest(for: folderId),
                    onRevealHandled: { requestId in
                        nav.clearRevealRequest(requestId: requestId)
                    },
                    playerViewModel: playerViewModel,
                    selectionActionBarConfig: $selectionActionBarConfig
                )
            } else {
                Text("Папка не найдена")
                    .libraryToolbar(title: "Ошибка")
                    .onAppear {
                        ToastManager.shared.handle(.folderNotFound)
                    }
            }
        }
    }

    // MARK: - Переадресация

    private func handlePendingShowTrack() {
        guard let trackId = nav.consumePendingShowTrackId() else { return }

        Task { @MainActor in
            guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
                ToastManager.shared.handle(.showInLibraryTargetMissing)
                return
            }

            let folderId = entry.folderId

            guard musicLibraryManager.folder(for: folderId) != nil else {
                ToastManager.shared.handle(.folderNotFound)
                return
            }

            nav.setPendingRevealRequest(folderId: folderId, targetTrackId: trackId)
            nav.openFolder(folderId)
        }
    }

    private func revealRequest(for folderId: UUID) -> LibraryRevealRequest? {
        guard nav.pendingRevealRequest?.folderId == folderId else { return nil }
        return nav.pendingRevealRequest
    }
}
