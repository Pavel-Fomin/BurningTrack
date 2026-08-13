//
//  ExportManager.swift
//  TrackList
//
//  Фасад экспорта треков.
//  Сначала получает папку через системный picker, затем передаёт копирование
//  в TrackExportService и не хранит состояние операции или UI.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation

@MainActor
final class ExportManager {

    /// Отдельный сервис выбора папки назначения.
    private let destinationResolver: any ExportDestinationResolving

    /// Отдельный actor, который выполняет подготовку и копирование файлов.
    private let trackExportService: TrackExportService

    /// Создаёт фасад с явно переданными зависимостями выбора назначения и копирования.
    init(
        destinationResolver: any ExportDestinationResolving,
        trackExportService: TrackExportService
    ) {
        self.destinationResolver = destinationResolver
        self.trackExportService = trackExportService
    }

    // MARK: - Экспорт после выбора папки

    /// Выбирает назначение и запускает самостоятельное копирование треков.
    func exportTracks(
        _ request: ExportRequest,
        onProgress: @escaping ExportProgressHandler = { _ in }
    ) async throws -> ExportSummary {
        let destination = try await destinationResolver.resolveDestination()

        let job = ExportJob(
            tracks: request.tracks,
            destination: destination,
            exportFolder: request.exportFolder,
            fileNamingMode: request.fileNamingMode
        )
        return try await trackExportService.export(
            job: job,
            onProgress: onProgress
        )
    }

    /// Отменяет picker или текущее копирование, если экспорт уже запущен.
    func cancelCurrentExport() {
        destinationResolver.cancelCurrentResolution()
        trackExportService.cancelCurrentExport()
    }
}
