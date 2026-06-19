//
//  TrackListExportHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает export-flow одного треклиста.
/// Отвечает за проверку пустого списка, получение presenter и запуск экспорта.
@MainActor
final class TrackListExportHandler {

    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Экспортер треков.
    private let exporter: any TrackExporting

    /// Провайдер верхнего UIViewController для системного picker.
    private let viewControllerProvider: any ViewControllerProviding

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    /// Создаёт обработчик export-flow одного треклиста.
    init(
        reader: any TrackListReading,
        exporter: any TrackExporting,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.reader = reader
        self.exporter = exporter
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    /// Экспортирует треки текущего треклиста.
    func exportTracks() {
        let tracks = reader.tracks

        guard !tracks.isEmpty else {
            toastPresenter.handle(.exportNoTracks)
            return
        }

        guard let topVC = viewControllerProvider.topViewController() else {
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        Task {
            do {
                _ = try await exporter.exportViaTempAndPicker(
                    tracks,
                    presenter: topVC
                )
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch {
                toastPresenter.handle(.exportFailed)
            }
        }
    }
}
