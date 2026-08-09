//
//  ExportDetailsRouting.swift
//  TrackList
//
//  Узкий маршрут экрана подробностей экспорта.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Неизменяемая идентичность одного открытия подробностей экспорта.
struct ExportDetailsSheetRoute: Identifiable, Equatable {

    /// Уникальный идентификатор конкретного AppSheet route.
    let id: UUID

    /// Создаёт новый route без callback-ов и изменяемого состояния feature.
    init(id: UUID = UUID()) {
        self.id = id
    }
}

/// Маршрутизирует только открытие и закрытие глобального экрана подробностей экспорта.
@MainActor
protocol ExportDetailsRouting: AnyObject {

    /// Открывает глобальный экран подробностей экспорта.
    func presentExportDetails() -> ExportDetailsSheetRoute

    /// Закрывает только route подробностей с переданной идентичностью.
    func dismissExportDetails(_ route: ExportDetailsSheetRoute)
}
