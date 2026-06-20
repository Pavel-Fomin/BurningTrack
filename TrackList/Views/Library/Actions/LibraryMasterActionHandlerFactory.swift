//
//  LibraryMasterActionHandlerFactory.swift
//  TrackList
//
//  Собирает production action handler для корневого flow фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
struct LibraryMasterActionHandlerFactory {

    /// Создаёт production action handler без DI-контейнера.
    func make(
        playerViewModel: PlayerViewModel,
        output: any LibraryMasterActionOutput,
        requestFolderPicker: @escaping @MainActor () -> Void
    ) -> LibraryMasterActionHandler {
        LibraryMasterActionHandler(
            manager: MusicLibraryManager.shared,
            navigationCoordinator: NavigationCoordinator.shared,
            toastPresenter: ToastManager.shared,
            playerViewModel: playerViewModel,
            output: output,
            requestFolderPicker: requestFolderPicker
        )
    }
}
