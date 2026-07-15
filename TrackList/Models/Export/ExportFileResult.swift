//
//  ExportFileResult.swift
//  TrackList
//
//  Результат обработки одного файла во время экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Содержит информацию о файле, который не удалось экспортировать.
struct ExportFileResult: Equatable, Identifiable, Sendable {

    /// Нумерованное имя файла в папке назначения.
    let fileName: String

    /// Техническое описание причины, пригодное для журнала или подробного UI.
    let errorDescription: String

    /// Имя файла уникально в рамках одного задания благодаря нумерации экспорта.
    var id: String { fileName }
}
