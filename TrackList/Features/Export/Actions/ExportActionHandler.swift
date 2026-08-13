//
//  ExportActionHandler.swift
//  TrackList
//
//  Выполнение пользовательского сценария глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

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

    /// Запускает готовый запрос экспорта и возвращает его итоговый результат.
    /// Внутренняя проверка сохраняет корректное сообщение при обходе внешнего ingress.
    func startExport(
        _ request: ExportRequest,
        onExportAccepted: () -> Void,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary? {
        guard request.tracks.isEmpty == false else {
            toastPresenter.handle(.exportNoTracks)
            return nil
        }

        onExportAccepted()

        do {
            return try await exporter.exportTracks(
                request,
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
                    .operationFailed(
                        message: ExportPresentationText.alreadyRunningMessage
                    )
                )
            } else {
                toastPresenter.handle(.exportFailed)
            }
            return nil
        } catch let resolverError as ExportDestinationResolverError {
            switch resolverError {
            case .presenterUnavailable:
                toastPresenter.handle(.presenterUnavailable)
            case .pickerAlreadyPresented, .selectedItemIsNotDirectory:
                toastPresenter.handle(
                    .operationFailed(
                        message: ExportPresentationText.destinationSelectionFailedMessage
                    )
                )
            }
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
