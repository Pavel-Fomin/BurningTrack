//
//  ExportProgress.swift
//  TrackList
//
//  Снимок состояния и прогресса операции экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Callback для доставки снимков прогресса из фонового сервиса в слой приложения.
typealias ExportProgressHandler = @Sendable (ExportProgress) -> Void

/// Содержит данные, необходимые для текущего и будущего UI прогресса экспорта.
struct ExportProgress: Equatable, Sendable {

    /// Имя источника, для которого формируется текущий экспорт.
    var sourceName: String

    /// Имя корневой папки, выбранной пользователем в системном picker-е.
    var rootDestinationName: String

    /// Общее количество треков в исходном задании, включая ошибочные.
    var totalFiles: Int

    /// Количество файлов, которые уже полностью записаны и переименованы.
    var completedFiles: Int

    /// Имя файла, обрабатываемого в данный момент.
    var currentFileName: String?

    /// Общий размер доступных для копирования файлов в байтах.
    var totalBytes: Int64

    /// Количество байтов текущего задания, записанных в завершённые файлы и текущий файл.
    var copiedBytes: Int64

    /// Размер текущего файла в байтах.
    var currentFileBytes: Int64

    /// Количество байтов текущего файла, записанных в частичный файл.
    var currentFileCopiedBytes: Int64

    /// Список файлов, пропущенных из-за индивидуальных ошибок.
    var failedFiles: [ExportFileResult]

    /// Текущая фаза операции.
    var state: ExportState

    /// Фактическое назначение, включая дочернюю папку текущего треклиста.
    var destination: ExportDestination

    /// Приблизительное оставшееся время; пока сервис его не рассчитывает.
    var estimatedSecondsRemaining: TimeInterval?

    /// Создаёт начальный снимок прогресса для задания экспорта.
    init(
        totalFiles: Int,
        destination: ExportDestination,
        sourceName: String? = nil,
        rootDestinationName: String? = nil,
        state: ExportState = .idle
    ) {
        self.sourceName = sourceName ?? destination.displayName
        self.rootDestinationName = rootDestinationName ?? destination.displayName
        self.totalFiles = totalFiles
        self.completedFiles = 0
        self.currentFileName = nil
        self.totalBytes = 0
        self.copiedBytes = 0
        self.currentFileBytes = 0
        self.currentFileCopiedBytes = 0
        self.failedFiles = []
        self.state = state
        self.destination = destination
        self.estimatedSecondsRemaining = nil
    }
}
