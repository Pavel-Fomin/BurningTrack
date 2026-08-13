//
//  ExportRequestHandling.swift
//  TrackList
//
//  Внешний контракт запуска глобального экспорта.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Принимает типизированные запросы запуска Export-feature от других функций приложения.
@MainActor
protocol ExportRequestHandling: AnyObject {

    /// Запускает глобальный экспорт по готовому пользовательскому запросу.
    func startExport(_ request: ExportRequest)
}
