//
//  LibraryFolderViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel экрана папки фонотеки.
//  Контейнер не должен знать детали сборки ViewModel и обработчиков.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
enum LibraryFolderViewModelFactory {
    // MARK: - Make

    static func make(
        folder: LibraryFolder,
        exportProgressViewModel: ExportProgressViewModel,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) -> LibraryFolderViewModel {
        // Используем overload вместо default-значения, чтобы обращаться к shared внутри MainActor.
        make(
            folder: folder,
            navigationCoordinator: .shared,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: ApplicationViewControllerProvider(),
            toastPresenter: ToastManager.shared,
            summaryProvider: makeSummaryProvider(),
            eventProvider: NotificationLibraryTrackEventProvider(),
            clearSelectionActionBar: clearSelectionActionBar
        )
    }

    static func make(
        folder: LibraryFolder,
        navigationCoordinator: NavigationCoordinator,
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting,
        summaryProvider: any TrackCollectionSummaryProviding,
        eventProvider: any LibraryTrackEventProvider,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) -> LibraryFolderViewModel {
        let stateBuilder = LibraryFolderStateBuilder()
        let actionHandler = LibraryFolderActionHandler(
            navigationCoordinator: navigationCoordinator,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter,
            exportFolderName: folder.name,
            clearSelectionActionBar: clearSelectionActionBar
        )
        return LibraryFolderViewModel(
            folder: folder,
            stateBuilder: stateBuilder,
            actionHandler: actionHandler,
            summaryProvider: summaryProvider,
            eventProvider: eventProvider
        )
    }

    /// Собирает единственный SQLite-компонент статистики для production-папки.
    private static func makeSummaryProvider() -> any TrackCollectionSummaryProviding {
        do {
            return try SQLiteTrackCollectionSummaryProvider()
        } catch {
            preconditionFailure("Не удалось создать SQLite-провайдер статистики: \(error)")
        }
    }
}
