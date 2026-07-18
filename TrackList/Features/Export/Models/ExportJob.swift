//
//  ExportJob.swift
//  TrackList
//
//  Модели задания и итогового результата экспорта треков.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Подготовленное к выполнению задание экспорта.
///
/// В задание передаются только Sendable-данные, нужные сервису: идентификатор
/// трека и итоговое нумерованное имя файла. Тяжёлая display-модель Track не
/// пересекает границу фонового сервиса.
struct ExportJob: Sendable {

    /// Один элемент задания экспорта.
    struct Item: Equatable, Sendable {

        /// Позиция трека в исходном порядке.
        let index: Int

        /// Идентификатор, через который BookmarkResolver получает исходный URL.
        let trackID: UUID

        /// Имя с сохранённой нумерацией текущего экспорта.
        let exportFileName: String
    }

    /// Файлы в порядке, выбранном пользователем или текущим треклистом.
    let items: [Item]

    /// Папка назначения, выбранная до запуска копирования.
    let destination: ExportDestination

    /// Имя дочерней папки, в которой должен храниться экспорт этого списка.
    let exportFolderName: String

    /// Создаёт задание и сохраняет текущую нумерацию файлов проекта.
    init(
        tracks: [Track],
        destination: ExportDestination,
        exportFolderName: String
    ) {
        self.items = tracks.enumerated().map { index, track in
            let prefix = String(format: "%02d", index + 1)
            return Item(
                index: index,
                trackID: track.trackId,
                exportFileName: "\(prefix) \(track.fileName)"
            )
        }
        self.destination = destination
        self.exportFolderName = exportFolderName
    }
}

/// Итог операции после обработки всех файлов, которые удалось подготовить.
struct ExportSummary: Sendable {

    /// Количество полностью записанных файлов.
    let completedFiles: Int

    /// Ошибки отдельных файлов, не остановившие остальную операцию.
    let failedFiles: [ExportFileResult]

    /// Финальное состояние операции.
    let state: ExportState
}
