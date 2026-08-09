//
//  MoveToFolderActionHandler.swift
//  TrackList
//
//  Типизированное закрытие Sheet Flow выбора папки.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Описывает намерения, завершающие текущий Move To Folder flow.
enum MoveToFolderAction {

    /// Пользователь явно отказался от выбора папки.
    case closeTapped

    /// Команда перемещения или копирования успешно завершилась.
    case operationCompleted
}

/// Выполняет только lifecycle-команду текущего Move To Folder route.
@MainActor
protocol MoveToFolderActionHandling: AnyObject {

    /// Обрабатывает typed-действие без доступа View к SheetManager.
    func handle(_ action: MoveToFolderAction)
}

/// Направляет typed-действия Move To Folder в узкий route-контракт.
@MainActor
final class MoveToFolderActionHandler: MoveToFolderActionHandling {

    /// Маршрутизирует закрытие только активного Move To Folder AppSheet.
    private let router: any MoveToFolderRouting
    /// Неизменяемая идентичность конкретного Move To Folder route.
    private let routeID: UUID

    /// Создаёт обработчик для production- или контролируемого тестового router-а.
    init(
        router: any MoveToFolderRouting,
        routeID: UUID
    ) {
        self.router = router
        self.routeID = routeID
    }

    /// Завершает route после пользовательского отказа или успешной файловой операции.
    func handle(_ action: MoveToFolderAction) {
        switch action {
        case .closeTapped, .operationCompleted:
            router.dismissMoveToFolder(routeID)
        }
    }
}

/// Закрывает конкретный Move To Folder route через общий lifecycle SheetManager.
@MainActor
protocol MoveToFolderRouting: AnyObject {

    /// Начинает dismiss, только если сейчас отображается совпадающий Move To Folder route.
    func dismissMoveToFolder(_ routeID: UUID)
}

extension SheetManager: MoveToFolderRouting {}
