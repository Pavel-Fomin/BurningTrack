//
//  ExportActionHandler.swift
//  TrackList
//
//  Выполнение пользовательского сценария глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import UIKit

/// Выполняет экспорт и преобразует ошибки доменного слоя в пользовательские сообщения.
@MainActor
final class ExportActionHandler {

    /// Выполняет выбор папки и потоковое копирование треков.
    private let exporter: any TrackExporting

    /// Показывает сообщения об отклонённом или неуспешном сценарии.
    private let toastPresenter: any ToastPresenting

    /// Создаёт обработчик с production- или тестовыми зависимостями.
    init(
        exporter: any TrackExporting,
        toastPresenter: any ToastPresenting
    ) {
        self.exporter = exporter
        self.toastPresenter = toastPresenter
    }

    /// Проверяет запрос, запускает экспорт и возвращает его итоговый результат.
    /// Пустой или неуспешный сценарий уже сопровождается пользовательским сообщением.
    func startExport(
        tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onExportAccepted: () -> Void,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary? {
        guard tracks.isEmpty == false else {
            toastPresenter.handle(.noTracksToExport)
            return nil
        }

        onExportAccepted()

        do {
            return try await exporter.exportTracks(
                tracks,
                exportFolderName: exportFolderName,
                presenter: presenter,
                onProgress: onProgress
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let appError as AppError {
            toastPresenter.handle(appError)
            return nil
        } catch let serviceError as TrackExportServiceError {
            if case .exportAlreadyRunning = serviceError {
                toastPresenter.handle(
                    .operationFailed(message: "Экспорт уже выполняется")
                )
            } else {
                toastPresenter.handle(.exportFailed)
            }
            return nil
        } catch let resolverError as ExportDestinationResolverError {
            toastPresenter.handle(
                .operationFailed(
                    message: resolverError.localizedDescription
                )
            )
            return nil
        } catch {
            toastPresenter.handle(.exportFailed)
            return nil
        }
    }

    /// Передаёт существующему экспортному фасаду запрос штатной отмены.
    func cancelCurrentExport() {
        exporter.cancelCurrentExport()
    }
}
