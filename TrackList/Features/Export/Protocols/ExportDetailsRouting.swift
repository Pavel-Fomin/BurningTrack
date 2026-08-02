//
//  ExportDetailsRouting.swift
//  TrackList
//
//  Узкий маршрут экрана подробностей экспорта.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Маршрутизирует только открытие и закрытие глобального экрана подробностей экспорта.
@MainActor
protocol ExportDetailsRouting: AnyObject {

    /// Открывает глобальный экран подробностей экспорта.
    func presentExportDetails()

    /// Закрывает экран подробностей, только если открыт именно экспорт.
    func closeExportDetailsIfNeeded()
}
