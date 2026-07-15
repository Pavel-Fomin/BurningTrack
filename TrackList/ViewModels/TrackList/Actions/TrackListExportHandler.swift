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

    /// Глобальная ViewModel, владеющая жизненным циклом экспорта.
    private let exportProgressViewModel: ExportProgressViewModel

    /// Провайдер верхнего UIViewController для системного picker.
    private let viewControllerProvider: any ViewControllerProviding

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    /// Создаёт обработчик export-flow одного треклиста.
    init(
        reader: any TrackListReading,
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.reader = reader
        self.exportProgressViewModel = exportProgressViewModel
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

        // Action handler не запускает копирование и не привязывает его к экрану.
        exportProgressViewModel.startExport(
            tracks: tracks,
            exportFolderName: reader.name,
            presenter: topVC
        )
    }
}
