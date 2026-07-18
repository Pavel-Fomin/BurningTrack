//
//  ExportOperationCoordinator.swift
//  TrackList
//
//  Жизненный цикл одной операции экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import UIKit

/// Владеет запуском, отменой и доставкой progress одной операции экспорта.
@MainActor
final class ExportOperationCoordinator {

    // MARK: - Events

    /// Сообщает, что ActionHandler принял непустой запрос на экспорт.
    var onExportAccepted: (@MainActor () -> Void)?

    /// Передаёт ViewModel снимок progress, относящийся к текущей операции.
    var onProgress: (@MainActor (ExportProgress) -> Void)?

    /// Сообщает, что координатор освободил ресурсы завершённой операции.
    var onOperationFinished: (@MainActor () -> Void)?

    // MARK: - Dependencies

    /// Выполняет сценарий запуска и штатной отмены экспорта.
    private let actionHandler: ExportActionHandler

    // MARK: - Operation lifecycle

    /// Удерживает текущую операцию независимой от экранов приложения.
    private var exportTask: Task<Void, Never>?

    /// Отделяет callback-и текущего запуска от запоздалых callback-ов прошлого.
    private var activeOperationID: UUID?

    /// Схлопывает быстрые callback-и до публикации на MainActor.
    private var progressRelay: ExportProgressRelay?

    // MARK: - Init

    /// Создаёт координатор с обработчиком сценария экспорта.
    init(actionHandler: ExportActionHandler) {
        self.actionHandler = actionHandler
    }

    // MARK: - State

    /// Показывает, что текущая операция ещё не завершила свой жизненный цикл.
    var isExportActive: Bool {
        exportTask != nil
    }

    // MARK: - Operation

    /// Запускает новую операцию, если предыдущая уже завершилась.
    @discardableResult
    func startExport(
        tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController
    ) -> Bool {
        guard exportTask == nil else { return false }

        let operationID = UUID()
        let relay = ExportProgressRelay()
        activeOperationID = operationID
        progressRelay = relay

        exportTask = Task { [weak self] in
            guard let self else { return }

            var exportWasAccepted = false

            defer {
                #if DEBUG
                if exportWasAccepted {
                    ExportDiagnostics.shared.end()
                }
                #endif
                self.finishOperation(operationID: operationID)
            }

            do {
                _ = try await self.actionHandler.startExport(
                    tracks: tracks,
                    exportFolderName: exportFolderName,
                    presenter: presenter,
                    onExportAccepted: {
                        exportWasAccepted = true

                        self.onExportAccepted?()

                        #if DEBUG
                        ExportDiagnostics.shared.begin(
                            exportID: operationID,
                            totalFiles: tracks.count
                        )
                        #endif
                    },
                    onProgress: { snapshot in
                        let shouldSchedule = relay.storeAndScheduleIfNeeded(snapshot)

                        #if DEBUG
                        ExportDiagnostics.shared.recordProgress(snapshot)

                        if shouldSchedule == false {
                            ExportDiagnostics.shared.recordDroppedProgress()
                        }
                        #endif

                        guard shouldSchedule else { return }

                        // Callback приходит из actor сервиса, поэтому публикация
                        // состояния возвращается в главный актор через короткую задачу.
                        #if DEBUG
                        ExportDiagnostics.shared.mainActorTaskCreated()
                        #endif
                        Task { @MainActor [weak self] in
                            defer {
                                #if DEBUG
                                ExportDiagnostics.shared.mainActorTaskFinished()
                                #endif
                            }

                            guard let latest = relay.takeLatestForDelivery(),
                                  let self else {
                                return
                            }
                            self.deliver(
                                latest,
                                operationID: operationID
                            )
                        }
                    }
                )

                deliverLatestProgress(
                    from: relay,
                    operationID: operationID
                )
            } catch is CancellationError {
                // Сервис сам отправляет состояние cancelled перед завершением.
                deliverLatestProgress(
                    from: relay,
                    operationID: operationID
                )
            } catch {
                // ActionHandler уже обработал ошибку экспорта.
                // Здесь сохраняем только доставку последнего снимка progress.
                deliverLatestProgress(
                    from: relay,
                    operationID: operationID
                )
            }
        }

        return true
    }

    /// Передаёт отмену в ActionHandler и отменяет текущую верхнеуровневую задачу.
    @discardableResult
    func cancelExport() -> Bool {
        guard let exportTask else { return false }

        // Сначала ActionHandler останавливает picker или FileHandle через
        // TrackExporting, затем существующая задача получает отмену.
        actionHandler.cancelCurrentExport()
        exportTask.cancel()
        return true
    }

    // MARK: - Progress delivery

    /// Передаёт ViewModel только обновления текущей операции.
    private func deliver(
        _ snapshot: ExportProgress,
        operationID: UUID
    ) {
        guard activeOperationID == operationID else { return }
        #if DEBUG
        ExportDiagnostics.shared.recordAppliedProgress()
        #endif
        onProgress?(snapshot)
    }

    /// Доставляет последний callback перед обработкой результата операции.
    private func deliverLatestProgress(
        from relay: ExportProgressRelay,
        operationID: UUID
    ) {
        guard let latest = relay.takeLatestImmediately() else { return }
        deliver(latest, operationID: operationID)
    }

    /// Освобождает ресурсы и разблокирует запуск следующей операции.
    private func finishOperation(operationID: UUID) {
        guard activeOperationID == operationID else { return }

        exportTask = nil
        activeOperationID = nil
        progressRelay = nil
        onOperationFinished?()
    }
}
