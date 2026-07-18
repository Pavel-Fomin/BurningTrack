//
//  ExportFeatureFactory.swift
//  TrackList
//
//  Сборка production-конфигурации функции экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

/// Собирает зависимости глобального состояния экспорта для production-приложения.
@MainActor
struct ExportFeatureFactory {

    /// Application-level фасад, который выбирает папку и запускает экспорт.
    private let exporter: any TrackExporting

    /// Единый получатель пользовательских сообщений экспортного сценария.
    private let toastPresenter: any ToastPresenting

    /// Создаёт фабрику с явно переданными production- или тестовыми зависимостями.
    init(
        exporter: any TrackExporting,
        toastPresenter: any ToastPresenting
    ) {
        self.exporter = exporter
        self.toastPresenter = toastPresenter
    }

    /// Создаёт фабрику с общими production-зависимостями приложения.
    init() {
        self.init(
            exporter: ExportManager.shared,
            toastPresenter: ToastManager.shared
        )
    }

    /// Собирает глобальную ViewModel и все зависимости жизненного цикла экспорта.
    func makeExportProgressViewModel() -> ExportProgressViewModel {
        let actionHandler = ExportActionHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        let coordinator = ExportOperationCoordinator(
            actionHandler: actionHandler
        )

        return ExportProgressViewModel(
            coordinator: coordinator,
            toastPresenter: toastPresenter
        )
    }
}
