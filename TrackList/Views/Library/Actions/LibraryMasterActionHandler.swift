//
//  LibraryMasterActionHandler.swift
//  TrackList
//
//  Обрабатывает действия корневого экрана фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class LibraryMasterActionHandler {

    /// Менеджер фонотеки для attach/detach операций.
    private let manager: MusicLibraryManager
    /// Координатор навигации внутри фонотеки.
    private let navigationCoordinator: NavigationCoordinator
    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting
    /// ViewModel плеера для проверки и остановки воспроизведения.
    private let playerViewModel: PlayerViewModel
    /// Output корневого flow для изменения экранного состояния.
    private let output: any LibraryMasterActionOutput
    /// Запрашивает показ системного picker'а папки на уровне экрана.
    private let requestFolderPicker: @MainActor () -> Void

    init(
        manager: MusicLibraryManager,
        navigationCoordinator: NavigationCoordinator,
        toastPresenter: any ToastPresenting,
        playerViewModel: PlayerViewModel,
        output: any LibraryMasterActionOutput,
        requestFolderPicker: @escaping @MainActor () -> Void
    ) {
        self.manager = manager
        self.navigationCoordinator = navigationCoordinator
        self.toastPresenter = toastPresenter
        self.playerViewModel = playerViewModel
        self.output = output
        self.requestFolderPicker = requestFolderPicker
    }

    /// Обрабатывает действие корневого экрана фонотеки.
    func handle(
        _ action: LibraryMasterAction
    ) {
        switch action {

        case .onAppear:
            output.refreshState()

        case .addFolderTapped:
            requestFolderPicker()

        case .folderPicked(let url):
            attachFolder(url)

        case .folderPickFailed:
            toastPresenter.handle(
                .operationFailed(message: "Не удалось выбрать папку")
            )

        case .openFolder(let folderId):
            openFolder(folderId)

        case .requestDetachFolder(let folderId):
            requestDetachFolder(folderId)

        case .confirmStopAndDetachFolder:
            confirmStopAndDetachFolder()

        case .cancelDetachFolder:
            output.clearPendingDetachFolder()
        }
    }

    /// Открывает папку, если она не находится в процессе прикрепления.
    private func openFolder(
        _ folderId: UUID
    ) {
        guard manager.isAttachingFolder(folderId) == false else { return }
        navigationCoordinator.openFolder(folderId)
    }

    /// Прикрепляет выбранную папку и показывает результат пользователю.
    private func attachFolder(
        _ url: URL
    ) {
        Task { @MainActor in
            do {
                try await manager.saveBookmark(for: url)
                toastPresenter.handle(
                    .folderAdded(name: url.lastPathComponent)
                )
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch {
                toastPresenter.handle(
                    .operationFailed(message: "Не удалось добавить папку")
                )
            }
        }
    }

    /// Проверяет, можно ли открепить папку сразу, или нужно показать предупреждение.
    private func requestDetachFolder(
        _ folderId: UUID
    ) {
        guard let folder = manager.folder(for: folderId) else {
            toastPresenter.handle(.folderNotFound)
            return
        }

        Task { @MainActor in
            let canDetach = await manager.canDetachFolder(
                url: folder.url,
                currentTrackId: playerViewModel.currentTrackDisplayable?.trackId,
                isPlaying: playerViewModel.isPlaying
            )

            if canDetach {
                await detachFolder(folder)
            } else {
                output.setPendingDetachFolder(folder)
            }
        }
    }

    /// Подтверждает остановку воспроизведения и открепляет ожидающую папку.
    private func confirmStopAndDetachFolder() {
        guard let folder = output.pendingDetachFolder else {
            output.clearPendingDetachFolder()
            return
        }

        // Если трек сейчас играет — ставим его на паузу
        if playerViewModel.isPlaying {
            playerViewModel.togglePlayPause()
        }

        Task { @MainActor in
            await detachFolder(folder)
            output.clearPendingDetachFolder()
        }
    }

    /// Открепляет папку и централизованно обрабатывает ошибки.
    private func detachFolder(
        _ folder: LibraryFolder
    ) async {
        do {
            try await manager.removeBookmark(for: folder.url)
            toastPresenter.handle(
                .folderRemoved(name: folder.name)
            )
        } catch let appError as AppError {
            toastPresenter.handle(appError)
        } catch {
            toastPresenter.handle(
                .operationFailed(message: "Не удалось открепить папку")
            )
        }
    }
}
