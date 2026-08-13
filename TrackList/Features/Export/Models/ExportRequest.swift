//
//  ExportRequest.swift
//  TrackList
//
//  Типизированный запрос на запуск глобального экспорта.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Описывает неизменяемые данные одного пользовательского запроса на экспорт.
struct ExportRequest {

    /// Треки, которые требуется экспортировать в сохранённом порядке.
    let tracks: [Track]

    /// Семантика дочерней папки внутри выбранного пользователем назначения.
    let exportFolder: ExportFolder

    /// Правило формирования имён экспортируемых файлов.
    let fileNamingMode: ExportFileNamingMode
}
