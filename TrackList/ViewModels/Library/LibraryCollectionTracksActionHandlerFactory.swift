//
//  LibraryCollectionTracksActionHandlerFactory.swift
//  TrackList
//
//  Собирает обработчик экспорта треков выбранного значения коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Собирает production-зависимости обработчика экспорта выбранного значения коллекции.
@MainActor
struct LibraryCollectionTracksActionHandlerFactory {

    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    /// Получает подготовленный Composition Root внешний контракт экспорта.
    init(exportRequestHandler: any ExportRequestHandling) {
        self.exportRequestHandler = exportRequestHandler
    }

    /// Создаёт обработчик для типизированного источника текущего списка и глобального экспорта.
    func make(
        source: LibraryTrackListSource
    ) -> LibraryCollectionTracksActionHandler {
        LibraryCollectionTracksActionHandler(
            source: source,
            exportRequestHandler: exportRequestHandler
        )
    }
}
