//
//  ExportProgressViewModel.swift
//  TrackList
//
//  Глобальное состояние и управление текущей операцией экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation
import UIKit

/// Хранит единое состояние экспорта для всех экранов приложения.
///
/// ViewModel владеет только маршрутом операции и опубликованным снимком
/// состояния. Само копирование остаётся в ExportManager и TrackExportService.
@MainActor
final class ExportProgressViewModel: ObservableObject {

    // MARK: - State

    /// Последний полученный снимок состояния экспорта.
    @Published private(set) var progress: ExportProgress?

    /// Показывает, что подробный экран экспорта уже запрошен.
    @Published private(set) var isShowingDetails = false

    // MARK: - Dependencies

    /// Единый фасад выбора папки и запуска фонового копирования.
    private let exporter: any TrackExporting

    /// Централизованный канал пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    // MARK: - Operation lifecycle

    /// Задача верхнего уровня удерживает операцию независимой от экранов.
    private var exportTask: Task<Void, Never>?

    /// Идентификатор операции отсекает запоздалые callback-и предыдущего запуска.
    private var activeOperationID: UUID?

    // MARK: - Init

    /// Создаёт ViewModel с production- или тестовыми зависимостями.
    init(
        exporter: any TrackExporting,
        toastPresenter: any ToastPresenting
    ) {
        self.exporter = exporter
        self.toastPresenter = toastPresenter
    }

    // MARK: - Derived state

    /// Показывает наличие результата или активного снимка экспорта.
    var isVisible: Bool {
        progress != nil
    }

    /// Не позволяет запускать вторую операцию во время выбора папки или копирования.
    var isExportActive: Bool {
        exportTask != nil
    }

    /// Кнопка отмены доступна только во время подготовки или копирования.
    var canCancel: Bool {
        guard exportTask != nil else { return false }
        guard let state = progress?.state else { return false }

        switch state {
        case .preparing, .copying:
            return true
        case .idle, .completed, .completedWithErrors, .cancelled, .failed:
            return false
        }
    }

    // MARK: - Export actions

    /// Запускает экспорт и оставляет его независимым от жизненного цикла экрана.
    func startExport(
        tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController
    ) {
        guard !tracks.isEmpty else {
            toastPresenter.handle(.noTracksToExport)
            return
        }

        guard exportTask == nil else {
            toastPresenter.handle(
                .operationFailed(message: "Экспорт уже выполняется")
            )
            return
        }

        let operationID = UUID()
        activeOperationID = operationID
        progress = nil
        isShowingDetails = false

        let exporter = exporter
        let relay = ExportProgressRelay()

        exportTask = Task { [weak self] in
            guard let self else { return }

            defer {
                self.finishOperation(operationID: operationID)
            }

            do {
                _ = try await exporter.exportTracks(
                    tracks,
                    exportFolderName: exportFolderName,
                    presenter: presenter,
                    onProgress: { snapshot in
                        relay.store(snapshot)

                        // Callback приходит из actor сервиса, поэтому публикация
                        // состояния возвращается в главный актор через отдельную задачу.
                        Task { @MainActor [weak self] in
                            guard let self,
                                  let latest = relay.takeLatest() else {
                                return
                            }
                            self.apply(
                                latest,
                                operationID: operationID
                            )
                        }
                    }
                )

                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )
            } catch is CancellationError {
                // Сервис сам отправляет состояние cancelled перед завершением.
                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )
            } catch let appError as AppError {
                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )
                toastPresenter.handle(appError)
            } catch let serviceError as TrackExportServiceError {
                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )

                if case .exportAlreadyRunning = serviceError {
                    toastPresenter.handle(
                        .operationFailed(message: "Экспорт уже выполняется")
                    )
                } else {
                    toastPresenter.handle(.exportFailed)
                }
            } catch let resolverError as ExportDestinationResolverError {
                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )
                toastPresenter.handle(
                    .operationFailed(
                        message: resolverError.localizedDescription
                    )
                )
            } catch {
                applyLatestProgress(
                    from: relay,
                    operationID: operationID
                )
                toastPresenter.handle(.exportFailed)
            }
        }
    }

    /// Запрашивает штатную отмену picker или фонового копирования.
    @discardableResult
    func cancelExport() -> Bool {
        guard exportTask != nil else { return false }

        // Сначала уведомляем фасад, чтобы закрыть picker или остановить FileHandle.
        exporter.cancelCurrentExport()
        exportTask?.cancel()

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
        guard exportTask == nil else { return }
        guard let state = progress?.state,
              state != .preparing,
              state != .copying else {
            return
        }

        progress = nil
        isShowingDetails = false
        closeDetailsSheetIfNeeded()
    }

    // MARK: - Progress delivery

    /// Принимает только обновления текущей операции.
    private func apply(
        _ snapshot: ExportProgress,
        operationID: UUID
    ) {
        guard activeOperationID == operationID else { return }
        progress = snapshot
    }

    /// Доставляет последний callback перед обработкой результата операции.
    private func applyLatestProgress(
        from relay: ExportProgressRelay,
        operationID: UUID
    ) {
        guard let latest = relay.takeLatest() else { return }
        apply(latest, operationID: operationID)
    }

    /// Освобождает блокировку повторного запуска после завершения текущей задачи.
    private func finishOperation(operationID: UUID) {
        guard activeOperationID == operationID else { return }

        exportTask = nil
        activeOperationID = nil
    }

    /// Закрывает только открытый экран деталей экспорта.
    private func closeDetailsSheetIfNeeded() {
        guard case .exportProgress = SheetManager.shared.activeSheet else {
            return
        }

        SheetManager.shared.closeActive()
    }
}

/// Потокобезопасно хранит последний callback до его публикации на MainActor.
private final class ExportProgressRelay: @unchecked Sendable {

    /// Защищает короткую операцию записи и чтения последнего снимка.
    private let lock = NSLock()

    /// Последний полученный снимок прогресса.
    private var latestProgress: ExportProgress?

    /// Сохраняет новый снимок из фонового callback-а.
    func store(_ progress: ExportProgress) {
        lock.lock()
        latestProgress = progress
        lock.unlock()
    }

    /// Забирает последний снимок для публикации на MainActor.
    func takeLatest() -> ExportProgress? {
        lock.lock()
        let progress = latestProgress
        latestProgress = nil
        lock.unlock()
        return progress
    }
}
