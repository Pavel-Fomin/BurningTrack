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

    /// Универсальный слой внешнего прогресса, не знающий о моделях экспорта.
    private let liveActivityManager: any ProgressLiveActivityManaging

    // MARK: - Operation lifecycle

    /// Удерживает текущую операцию независимой от экранов приложения.
    private var exportTask: Task<Void, Never>?

    /// Отделяет callback-и текущего запуска от запоздалых callback-ов прошлого.
    private var activeOperationID: UUID?

    /// Схлопывает быстрые callback-и до публикации на MainActor.
    private var progressRelay: ExportProgressRelay?

    /// Отделяет Activity текущего запуска от Activity предыдущего запуска.
    private var liveActivityOperationID: UUID?

    /// Рассчитывает оставшееся время по тем же доставленным снимкам операции.
    private var timeEstimator = OperationTimeEstimator()

    /// Последняя дата завершения, разрешённая к передаче в Activity.
    private var estimatedEndDate: Date?

    /// Отмечает запуск расчёта времени после перехода к фактическому копированию.
    private var isTimeEstimationStarted = false

    /// Название папки, выбранное для текущей операции и показанное пользователю.
    private var liveActivitySubjectTitle = ""

    // MARK: - Init

    /// Создаёт координатор с обработчиком сценария экспорта.
    init(actionHandler: ExportActionHandler) {
        self.actionHandler = actionHandler
        self.liveActivityManager = UnavailableProgressLiveActivityManager()
    }

    /// Создаёт Coordinator с явно переданным универсальным слоем внешнего прогресса.
    init(
        actionHandler: ExportActionHandler,
        liveActivityManager: any ProgressLiveActivityManaging
    ) {
        self.actionHandler = actionHandler
        self.liveActivityManager = liveActivityManager
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
        liveActivityOperationID = nil
        estimatedEndDate = nil
        isTimeEstimationStarted = false
        liveActivitySubjectTitle = exportFolderName
        timeEstimator.stop()

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

        let liveActivityProgress = makeOperationProgress(from: snapshot)
        publishLiveActivityProgress(
            liveActivityProgress,
            operationID: operationID,
            subjectTitle: liveActivitySubjectTitle
        )

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
        liveActivityOperationID = nil
        estimatedEndDate = nil
        isTimeEstimationStarted = false
        liveActivitySubjectTitle = ""
        timeEstimator.stop()
        onOperationFinished?()
    }

    // MARK: - Live Activity progress

    /// Преобразует экспортный снимок в абстрактную модель внешнего прогресса.
    /// Здесь заканчивается знание об ExportProgress и начинается универсальный слой.
    private func makeOperationProgress(
        from snapshot: ExportProgress
    ) -> OperationProgress {
        let phase: ProgressActivityPhase
        switch snapshot.state {
        case .idle, .preparing:
            phase = .preparing
        case .copying:
            phase = .running
        case .completed:
            phase = .completed
        case .completedWithErrors, .failed:
            // Activity не показывает технические детали и сообщает общий результат.
            phase = .failed
        case .cancelled:
            phase = .cancelled
        }

        switch phase {
        case .preparing:
            break
        case .running:
            startTimeEstimationIfNeeded()
            let estimationUnits = liveActivityEstimationUnits(from: snapshot)

            if let newEstimatedEndDate = timeEstimator.recordProgress(
                completedUnits: estimationUnits.completed,
                totalUnits: estimationUnits.total,
                date: Date()
            ) {
                guard let estimatedEndDate else {
                    self.estimatedEndDate = newEstimatedEndDate
                    break
                }

                if abs(newEstimatedEndDate.timeIntervalSince(estimatedEndDate))
                    >= ProgressLiveActivityManager.estimatedEndDateUpdateThreshold {
                    self.estimatedEndDate = newEstimatedEndDate
                }
            }
        case .completed, .failed, .cancelled:
            // После фактического окончания операции прогноз больше не нужен.
            timeEstimator.stop()
            isTimeEstimationStarted = false
            estimatedEndDate = nil
        }

        return OperationProgress(
            completedUnits: max(snapshot.completedFiles, 0),
            totalUnits: max(snapshot.totalFiles, 0),
            estimatedEndDate: estimatedEndDate,
            phase: phase
        )
    }

    /// Начинает измерять скорость только после перехода к копированию байтов.
    /// Подготовка файлов не должна искусственно замедлять первую оценку ETA.
    private func startTimeEstimationIfNeeded() {
        guard !isTimeEstimationStarted else { return }

        isTimeEstimationStarted = true
        estimatedEndDate = nil
        timeEstimator.reset(startDate: Date())
    }

    /// Возвращает байтовый прогресс для стабильной оценки времени экспорта.
    /// Количество файлов остаётся пользовательским прогрессом, но не подходит
    /// для ETA: длительность копирования треков зависит от их размера.
    private func liveActivityEstimationUnits(
        from snapshot: ExportProgress
    ) -> (completed: Int64, total: Int64) {
        guard snapshot.totalBytes > 0 else {
            return (
                completed: Int64(max(snapshot.completedFiles, 0)),
                total: Int64(max(snapshot.totalFiles, 0))
            )
        }

        let totalBytes = max(snapshot.totalBytes, 0)
        return (
            completed: min(max(snapshot.copiedBytes, 0), totalBytes),
            total: totalBytes
        )
    }

    /// Передаёт первый, изменившийся и итоговый снимок универсальному менеджеру.
    private func publishLiveActivityProgress(
        _ progress: OperationProgress,
        operationID: UUID,
        subjectTitle: String
    ) {
        if liveActivityOperationID != operationID {
            liveActivityOperationID = operationID
            liveActivityManager.start(
                operationID: operationID,
                operationTitle: "Экспорт",
                subjectTitle: subjectTitle,
                progress: progress
            )
        }

        switch progress.phase {
        case .completed, .failed, .cancelled:
            liveActivityManager.finish(
                operationID: operationID,
                progress: progress
            )
        case .preparing, .running:
            liveActivityManager.update(
                operationID: operationID,
                progress: progress
            )
        }
    }
}
