//
//  LibraryAllTracksActionHandlerFactory.swift
//  TrackList
//
//  Собирает обработчик действий общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Собирает production-зависимости обработчика экспорта общего списка треков.
@MainActor
struct LibraryAllTracksActionHandlerFactory {

    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    /// Получает подготовленный Composition Root внешний контракт экспорта.
    init(exportRequestHandler: any ExportRequestHandling) {
        self.exportRequestHandler = exportRequestHandler
    }

    /// Создаёт обработчик действий для типизированного глобального экспорта.
    func make() -> LibraryAllTracksActionHandler {
        LibraryAllTracksActionHandler(
            exportRequestHandler: exportRequestHandler
        )
    }
}
