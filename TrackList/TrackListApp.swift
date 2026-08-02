//
//  TrackListApp.swift
//  TrackList
//
//  файл запуска SwiftUI-приложения
//  PlayerViewModel — управляет воспроизведением
//
//  Created by Pavel Fomin on 28.04.2025.
//


import SwiftUI

@main
struct TrackListApp: App {

    /// Единый менеджер воспроизведения используется плеером и глобальными файловыми сценариями.
    let playerManager: PlayerManager
    let playerViewModel: PlayerViewModel
    /// Единый обработчик «Избранного» передаётся во все production-сценарии приложения.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовый обработчик переименования файлов сохраняется на весь жизненный цикл приложения.
    let renameActionHandler: TrackFileRenameActionHandler

    /// Глобальная ViewModel сохраняет экспорт при смене вкладок и закрытии picker-а.
    @StateObject private var exportProgressViewModel: ExportProgressViewModel
    
    init() {
        do {
            // Открываем постоянное SQLite-хранилище один раз при старте приложения.
            try AppDatabase.shared.open()
        } catch {
            // Инфраструктура БД критична для следующих фаз, поэтому ошибка должна быть заметна сразу.
            preconditionFailure("Не удалось подготовить SQLite-хранилище: \(error.localizedDescription)")
        }

        let favoritesEventCenter = FavoritesEventCenter.shared
        let favoritesService = FavoritesService(
            trackListsManager: TrackListsManager.shared,
            trackListManager: TrackListManager.shared,
            favoritesEvents: favoritesEventCenter
        )
        let favoriteTrackActionHandler = FavoriteTrackActionHandler(
            favoritesService: favoritesService
        )
        let playerManager = PlayerManager()
        let playerVM = PlayerViewModel(
            playerManager: playerManager,
            favoritesService: favoritesService,
            favoriteActionHandler: favoriteTrackActionHandler,
            favoritesEvents: favoritesEventCenter
        )
        let renameActionHandler = TrackFileRenameActionHandler(
            playerManager: playerManager,
            sheetManager: SheetManager.shared,
            commandExecutor: AppCommandExecutor.shared,
            toastManager: ToastManager.shared,
            proposalBuilder: FileRenameProposalBuilder()
        )
        self.playerManager = playerManager
        self.playerViewModel = playerVM
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.renameActionHandler = renameActionHandler
        // Фабрика скрывает внутреннюю последовательность сборки export feature.
        let exportFeatureFactory = ExportFeatureFactory(
            exporter: ExportManager.shared,
            toastPresenter: ToastManager.shared,
            detailsRouter: SheetManager.shared
        )
        _exportProgressViewModel = StateObject(
            wrappedValue: exportFeatureFactory.makeExportProgressViewModel()
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel,
                playerManager: playerManager,
                favoriteTrackActionHandler: favoriteTrackActionHandler,
                renameActionHandler: renameActionHandler
            )
            .environmentObject(SheetManager.shared)
            .environmentObject(exportProgressViewModel)
        }
    }
}
