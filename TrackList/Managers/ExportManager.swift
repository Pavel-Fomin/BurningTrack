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
import UIKit

@MainActor
final class ExportManager {

    /// Единый production-фасад, используемый текущими action handler-ами.
    static let shared = ExportManager()

    /// Отдельный сервис выбора папки назначения.
    private let destinationResolver: any ExportDestinationResolving

    /// Отдельный actor, который выполняет подготовку и копирование файлов.
    private let trackExportService: TrackExportService

    /// Создаёт фасад с production-зависимостями или тестовыми реализациями.
    init(
        destinationResolver: (any ExportDestinationResolving)? = nil,
        trackExportService: TrackExportService? = nil
    ) {
        self.destinationResolver = destinationResolver ?? ExportDestinationResolver()
        self.trackExportService = trackExportService ?? TrackExportService()
    }

    // MARK: - Экспорт после выбора папки

    /// Выбирает папку и запускает самостоятельное копирование треков.
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler = { _ in }
    ) async throws -> ExportSummary {
        let destination = try await destinationResolver.resolveDestination(
            presenter: presenter
        )

        let job = ExportJob(
            tracks: tracks,
            destination: destination,
            exportFolderName: exportFolderName
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
