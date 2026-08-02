//
//  PlayerFeatureDependencies.swift
//  TrackList
//
//  Явные production-зависимости Player feature.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Хранит только готовые зависимости, необходимые фабрикам Player feature.
/// Тип не разрешает singleton и не выполняет пользовательские сценарии.
@MainActor
struct PlayerFeatureDependencies {

    /// Единое presentation-состояние sheet приложения.
    let sheetManager: SheetManager
    /// Хранилище очереди, общее для PlayerViewModel и экранного flow.
    let playlistManager: PlaylistManager
    /// Настройки, влияющие на presentation очереди плеера.
    let appSettingsManager: AppSettingsManager
    /// Исполнитель доменных команд очереди.
    let commandExecutor: AppCommandExecutor
    /// Единый презентер пользовательских сообщений.
    let toastManager: ToastManager
    /// Маршрутизатор presentation-действий из строки плеера.
    let sheetActionCoordinator: SheetActionCoordinator
    /// Обработчик переходов к значениям музыкальной коллекции.
    let collectionNavigationHandler: TrackCollectionNavigationHandler
    /// Общий action flow отправки трека.
    let trackShareActionHandler: TrackShareActionHandler
    /// Общий action flow переименования файлов.
    let trackFileRenameActionHandler: TrackFileRenameActionHandler
    /// Источник metadata для presentation состояния строк плеера.
    let trackRegistry: TrackRegistry
}
