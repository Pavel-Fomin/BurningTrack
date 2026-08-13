//
//  ExportProgressViewModel.swift
//  TrackList
//
//  Глобальное опубликованное состояние текущей операции экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

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

    /// Показывает, что текущий route подробностей ещё не сообщил о своём исчезновении.
    @Published private(set) var isShowingDetails = false

    /// Показывает, что Coordinator ещё не завершил текущую экспортную операцию.
    @Published private(set) var isExportActive = false

    // MARK: - Dependencies

    /// Владеет жизненным циклом одной экспортной операции.
    private let coordinator: ExportOperationCoordinator

    /// Сообщает о повторном запуске, который отклоняется жизненным циклом ViewModel.
    private let toastPresenter: any ToastPresenting

    /// Идентичность route подробностей, ожидающего lifecycle-событие SwiftUI.
    private(set) var detailsRoute: ExportDetailsSheetRoute?

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

    /// Запускает экспорт и оставляет его независимым от жизненного цикла экрана.
    func startExport(_ request: ExportRequest) {
        guard coordinator.startExport(request) else {
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

        return true
    }

    /// Фиксирует route подробностей, для которого ActionHandler уже отправил typed-команду.
    func detailsPresentationWasRequested(for route: ExportDetailsSheetRoute) {
        isShowingDetails = true
        detailsRoute = route
    }

    /// Синхронизирует feature-state только с исчезновением того же route.
    func detailsDidDisappear(for route: ExportDetailsSheetRoute) {
        guard detailsRoute == route else { return }

        isShowingDetails = false
        detailsRoute = nil
    }

    /// Удаляет завершённый результат после явного действия пользователя.
    @discardableResult
    func dismissCompletedExport() -> Bool {
        guard isExportActive == false else { return false }
        guard let state = progress?.state,
              state != .preparing,
              state != .copying else {
            return false
        }

        progress = nil
        return true
    }

    // MARK: - Coordinator events

    /// Очищает отображаемое состояние только после принятия сценария экспорта.
    private func exportWasAccepted() {
        progress = nil
        isShowingDetails = false
        detailsRoute = nil
    }

    /// Сохраняет снимок, который Coordinator признал частью текущей операции.
    private func apply(_ snapshot: ExportProgress) {
        progress = snapshot
    }

    /// Отражает завершение жизненного цикла, не управляя Task напрямую.
    private func finishOperation() {
        isExportActive = false
    }

}
