//
//  ExportRequestActionHandler.swift
//  TrackList
//
//  Внешняя точка входа для запуска глобального экспорта.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Принимает запросы других функций и передаёт их глобальному жизненному циклу Export.
@MainActor
final class ExportRequestActionHandler: ExportRequestHandling {

    /// ViewModel владеет опубликованным состоянием глобального экспорта.
    private let progressViewModel: ExportProgressViewModel

    /// Показывает единое сообщение при некорректном пользовательском запросе.
    private let toastPresenter: any ToastPresenting

    /// Создаёт внешний обработчик запуска Export-feature.
    init(
        progressViewModel: ExportProgressViewModel,
        toastPresenter: any ToastPresenting
    ) {
        self.progressViewModel = progressViewModel
        self.toastPresenter = toastPresenter
    }

    /// Проверяет входной запрос и запускает существующий глобальный export-flow.
    func startExport(_ request: ExportRequest) {
        guard request.tracks.isEmpty == false else {
            toastPresenter.handle(.exportNoTracks)
            return
        }

        progressViewModel.startExport(request)
    }
}
