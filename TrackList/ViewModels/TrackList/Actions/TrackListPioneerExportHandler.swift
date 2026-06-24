//
//  TrackListPioneerExportHandler.swift
//  TrackList
//
//  Обработчик тестового Pioneer USB Export для одного треклиста.
//

import Foundation

/// Обрабатывает пользовательский flow выбора папки и запуска Pioneer USB Export.
@MainActor
final class TrackListPioneerExportHandler {
    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Сервис записи структуры PIONEER.
    private let exportService: PioneerDeckExportService

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    /// Запрашивает показ системного picker'а папки на уровне View.
    private let requestDestinationPicker: @MainActor () -> Void

    /// Создаёт обработчик тестового Pioneer USB Export.
    init(
        reader: any TrackListReading,
        exportService: PioneerDeckExportService,
        toastPresenter: any ToastPresenting,
        requestDestinationPicker: @escaping @MainActor () -> Void
    ) {
        self.reader = reader
        self.exportService = exportService
        self.toastPresenter = toastPresenter
        self.requestDestinationPicker = requestDestinationPicker
    }

    /// Запрашивает выбор папки назначения, если в треклисте есть треки.
    func requestExport() {
        guard reader.tracks.isEmpty == false else {
            toastPresenter.handle(.noTracksToExport)
            return
        }

        requestDestinationPicker()
    }

    /// Запускает запись PIONEER-структуры в выбранную папку.
    func export(to destinationURL: URL) {
        guard let trackList = reader.currentTrackList else {
            toastPresenter.handle(.operationFailed(message: "Не удалось подготовить треклист"))
            return
        }

        Task { @MainActor in
            do {
                try await exportService.export(
                    trackList: trackList,
                    to: destinationURL
                )
                toastPresenter.handle(
                    .pioneerUSBExportCompleted(trackListName: trackList.name)
                )
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch let localizedError as LocalizedError {
                toastPresenter.handle(
                    .operationFailed(
                        message: localizedError.errorDescription ?? "Не удалось выполнить Pioneer USB Export"
                    )
                )
            } catch {
                toastPresenter.handle(
                    .operationFailed(message: "Не удалось выполнить Pioneer USB Export")
                )
            }
        }
    }

    /// Сообщает пользователю, что папку назначения выбрать не удалось.
    func handleDestinationPickFailed() {
        toastPresenter.handle(
            .operationFailed(message: "Не удалось выбрать папку")
        )
    }
}
