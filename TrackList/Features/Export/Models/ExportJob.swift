//
//  ExportJob.swift
//  TrackList
//
//  Модели задания и итогового результата экспорта треков.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Определяет способ формирования итогового имени файла при экспорте.
enum ExportFileNamingMode: Sendable {

    /// Добавляет к исходному имени файла двухзначный порядковый номер.
    case numbered

    /// Передаёт исходное имя файла без изменений.
    case original
}

/// Подготовленное к выполнению задание экспорта.
///
/// В задание передаются только Sendable-данные, нужные сервису: идентификатор
/// трека и итоговое имя файла. Тяжёлая display-модель Track не
/// пересекает границу фонового сервиса.
struct ExportJob: Sendable {

    /// Один элемент задания экспорта.
    struct Item: Equatable, Sendable {

        /// Позиция трека в исходном порядке.
        let index: Int

        /// Идентификатор, через который BookmarkResolver получает исходный URL.
        let trackID: UUID

        /// Итоговое имя файла, подготовленное для сервиса экспорта.
        let exportFileName: String
    }

    /// Файлы в порядке, выбранном пользователем или текущим треклистом.
    let items: [Item]

    /// Папка назначения, выбранная до запуска копирования.
    let destination: ExportDestination

    /// Имя дочерней папки, в которой должен храниться экспорт этого списка.
    let exportFolderName: String

    /// Создаёт задание и формирует имена файлов в выбранном режиме.
    init(
        tracks: [Track],
        destination: ExportDestination,
        exportFolderName: String,
        fileNamingMode: ExportFileNamingMode
    ) {
        self.items = tracks.enumerated().map { index, track in
            let exportFileName: String

            switch fileNamingMode {
            case .numbered:
                let prefix = String(format: "%02d", index + 1)
                exportFileName = "\(prefix) \(track.fileName)"
            case .original:
                exportFileName = track.fileName
            }

            return Item(
                index: index,
                trackID: track.trackId,
                exportFileName: exportFileName
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
