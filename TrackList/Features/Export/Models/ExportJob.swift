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
/// В задание передаются только Sendable-данные, нужные сервису: тип источника
/// и итоговое имя файла. Тяжёлая display-модель Track не пересекает границу
/// фонового сервиса.
struct ExportJob: Sendable {

    /// Один элемент задания экспорта.
    struct Item: Equatable, Sendable {

        /// Разделяет bookmark-файлы фонотеки и runtime-ассеты MediaPlayer.
        enum Source: Equatable, Sendable {
            /// Обычный файл восстанавливается по идентификатору через BookmarkResolver.
            case bookmark(trackID: UUID)
            /// iTunes-источник использует только готовый assetURL, если он доступен.
            case purchasedITunes(
                trackID: UUID,
                asset: PurchasedITunesAsset?
            )
        }

        /// Позиция трека в исходном порядке.
        let index: Int

        /// Типизированный источник не позволяет отправить iTunes-трек в BookmarkResolver.
        let source: Source

        /// Для обычного файла содержит полное имя, а для iTunes — основу без расширения.
        let exportFileName: String

        /// Сохраняет прежний доступ к идентификатору независимо от типа источника.
        var trackID: UUID {
            switch source {
            case .bookmark(let trackID):
                return trackID
            case .purchasedITunes(let trackID, _):
                return trackID
            }
        }
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
            let source: Item.Source
            let sourceFileName: String

            if track.source == .purchasedITunes {
                let asset = PurchasedITunesAsset(track: track)
                source = .purchasedITunes(
                    trackID: track.trackId,
                    asset: asset
                )
                // Формат Artist - Title задаётся общим writer-ом до добавления
                // фактического расширения выбранного плана AVFoundation.
                sourceFileName = asset.map(
                    PurchasedITunesAssetWriter.displayFileBaseName(for:)
                ) ?? track.fileName
            } else {
                source = .bookmark(trackID: track.trackId)
                sourceFileName = track.fileName
            }

            let exportFileName: String

            switch fileNamingMode {
            case .numbered:
                let prefix = String(format: "%02d", index + 1)
                exportFileName = "\(prefix) \(sourceFileName)"
            case .original:
                exportFileName = sourceFileName
            }

            return Item(
                index: index,
                source: source,
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
