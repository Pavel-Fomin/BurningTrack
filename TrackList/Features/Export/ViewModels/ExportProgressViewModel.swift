//
//  ExportProgressViewModel.swift
//  TrackList
//
//  Глобальное опубликованное состояние текущей операции экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation
import UIKit

/// Хранит единое состояние экспорта для всех экранов приложения.
///
/// ViewModel хранит опубликованное состояние интерфейса и получает события
/// операции от ExportOperationCoordinator. Само копирование остаётся в ExportManager
/// и TrackExportService.
@MainActor
final class ExportProgressViewModel: ObservableObject {

    // MARK: - State

    /// Последний полученный снимок состояния экспорта.
    @Published private(set) var progress: ExportProgress?

    /// Показывает, что подробный экран экспорта уже запрошен.
    @Published private(set) var isShowingDetails = false

    /// Показывает, что Coordinator ещё не завершил текущую экспортную операцию.
    @Published private(set) var isExportActive = false

    // MARK: - Dependencies

    /// Владеет жизненным циклом одной экспортной операции.
    private let coordinator: ExportOperationCoordinator

    /// Сообщает о повторном запуске, который отклоняется жизненным циклом ViewModel.
    private let toastPresenter: any ToastPresenting

    /// Преобразует внутренние данные операции в единый снимок интерфейса.
    private let exportPresenter = ExportPresenter()

    // MARK: - Init

    /// Создаёт ViewModel с координатором операции и сообщением повторного запуска.
    init(
        coordinator: ExportOperationCoordinator,
        toastPresenter: any ToastPresenting
    ) {
        self.coordinator = coordinator
        self.toastPresenter = toastPresenter

        coordinator.onExportAccepted = { [weak self] in
            self?.exportWasAccepted()
        }
        coordinator.onProgress = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        coordinator.onOperationFinished = { [weak self] in
            self?.finishOperation()
        }
    }

    // MARK: - Derived state

    /// Показывает наличие результата или активного снимка экспорта.
    var isVisible: Bool {
        screenState.isVisible
    }

    /// Кнопка отмены доступна только во время подготовки или копирования.
    var canCancel: Bool {
        screenState.canCancel
    }

    /// Собирает единый снимок интерфейса из существующих источников состояния.
    /// Вычисляемое свойство не создаёт второй изменяемый источник истины.
    var screenState: ExportScreenState {
        exportPresenter.makeScreenState(
            progress: progress,
            isShowingDetails: isShowingDetails,
            isExportActive: isExportActive
        )
    }

    // MARK: - Export actions

    /// Направляет действие интерфейса в существующий маршрут экспорта.
    func handle(_ action: ExportAction) {
        switch action {
        case let .start(tracks, exportFolder, fileNamingMode, presenter):
            startExport(
                tracks: tracks,
                exportFolder: exportFolder,
                fileNamingMode: fileNamingMode,
                presenter: presenter
            )
        case .cancel:
            cancelExport()
        case .presentDetails:
            presentDetails()
        case .dismissDetails:
            dismissDetails()
        case .detailsDidDisappear:
            detailsDidDisappear()
        case .dismissCompleted:
            dismissCompletedExport()
        }
    }

    /// Запускает экспорт и оставляет его независимым от жизненного цикла экрана.
    func startExport(
        tracks: [Track],
        exportFolder: ExportFolder,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController
    ) {
        guard coordinator.startExport(
            tracks: tracks,
            exportFolder: exportFolder,
            fileNamingMode: fileNamingMode,
            presenter: presenter
        ) else {
            toastPresenter.handle(
                .operationFailed(
                    message: ExportPresentationText.alreadyRunningMessage
                )
            )
            return
        }

        isExportActive = true
    }

    /// Запрашивает штатную отмену picker или фонового копирования.
    @discardableResult
    func cancelExport() -> Bool {
        guard coordinator.cancelExport() else { return false }

        // После принятия запроса отмены подробный экран больше не нужен:
        // итоговое состояние останется доступным в компактной панели.
        dismissDetails()
        return true
    }

    /// Открывает подробный результат через существующий глобальный SheetManager.
    func presentDetails() {
        guard progress != nil else { return }

        isShowingDetails = true
        SheetManager.shared.present(.exportProgress)
    }

    /// Закрывает подробный экран, не меняя результат операции.
    func dismissDetails() {
        isShowingDetails = false
        closeDetailsSheetIfNeeded()
    }

    /// Запоминает закрытие подробного экрана системным жестом.
    func detailsDidDisappear() {
        isShowingDetails = false
    }

    /// Удаляет завершённый результат после явного действия пользователя.
    func dismissCompletedExport() {
        guard isExportActive == false else { return }
        guard let state = progress?.state,
              state != .preparing,
              state != .copying else {
            return
        }

        progress = nil
        isShowingDetails = false
        closeDetailsSheetIfNeeded()
    }

    // MARK: - Coordinator events

    /// Очищает отображаемое состояние только после принятия сценария экспорта.
    private func exportWasAccepted() {
        progress = nil
        isShowingDetails = false
    }

    /// Сохраняет снимок, который Coordinator признал частью текущей операции.
    private func apply(_ snapshot: ExportProgress) {
        progress = snapshot
    }

    /// Отражает завершение жизненного цикла, не управляя Task напрямую.
    private func finishOperation() {
        isExportActive = false
    }

    /// Закрывает только открытый экран деталей экспорта.
    private func closeDetailsSheetIfNeeded() {
        guard case .exportProgress = SheetManager.shared.activeSheet else {
            return
        }

        SheetManager.shared.closeActive()
    }
}
