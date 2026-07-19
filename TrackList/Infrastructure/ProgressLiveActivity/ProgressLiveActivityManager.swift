//
//  ProgressLiveActivityManager.swift
//  TrackList
//
//  ActivityKit-реализация универсального менеджера прогресса.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Управляет одной универсальной Live Activity и не раскрывает ActivityKit экспорту.
@MainActor
final class ProgressLiveActivityManager: ProgressLiveActivityManaging {

    /// Минимальная разница между двумя расчётными датами для публикации в Activity.
    /// Благодаря порогу Activity не получает ежесекундные обновления только из-за таймера.
    static let estimatedEndDateUpdateThreshold: TimeInterval = 12

    /// Последовательная очередь жизненного цикла ActivityKit-вызовов.
    private var lifecycleTail: Task<Void, Never>?

    /// Идентификатор операции, которая сейчас владеет менеджером.
    private var activeOperationID: UUID?

    /// Последний снимок, уже разрешённый к публикации в Activity.
    private var lastPublishedProgress: OperationProgress?

    /// Терминальный снимок операции, ожидающий завершения Activity.
    private var finishedOperationID: UUID?

#if canImport(ActivityKit)
    /// Единственная Activity, созданная этим экземпляром менеджера.
    private var activity: Activity<ProgressActivityAttributes>?

    /// Идентификатор операции, которой принадлежит сохранённая Activity.
    private var activityOperationID: UUID?
#endif

    /// Запускает Activity после завершения уже запланированных действий старой операции.
    func start(
        operationID: UUID,
        operationTitle: String,
        subjectTitle: String,
        progress: OperationProgress
    ) {
        activeOperationID = operationID
        finishedOperationID = nil
        lastPublishedProgress = progress

        let previousTask = lifecycleTail
        lifecycleTail = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self,
                  self.activeOperationID == operationID else {
                return
            }

#if canImport(ActivityKit)
            guard #available(iOS 16.2, *) else {
                PersistentLogger.log(
                    "ProgressLiveActivityManager: ActivityKit недоступен на этой версии iOS"
                )
                return
            }

            await self.finishExistingActivities(with: progress)
            guard self.activeOperationID == operationID else { return }

            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                // Запрет пользователя равнозначен отсутствию менеджера:
                // экспорт продолжает работу без внешнего прогресса.
                PersistentLogger.log(
                    "ProgressLiveActivityManager: Live Activities отключены пользователем"
                )
                return
            }

            do {
                let attributes = ProgressActivityAttributes(
                    operationTitle: operationTitle,
                    subjectTitle: subjectTitle
                )
                let newActivity = try self.requestActivity(
                    attributes: attributes,
                    progress: progress
                )

                guard self.activeOperationID == operationID else {
                    await self.endActivity(
                        newActivity,
                        progress: progress,
                        dismissalPolicy: .immediate
                    )
                    return
                }

                self.activity = newActivity
                self.activityOperationID = operationID
            } catch {
                // ActivityKit остаётся необязательным слоем: ошибка запуска
                // фиксируется для диагностики, но не меняет выполнение операции.
                PersistentLogger.log(
                    "ProgressLiveActivityManager: не удалось запустить Activity: \(error)"
                )
            }
#else
            // На платформе без ActivityKit контракт намеренно ничего не делает.
            _ = operationTitle
            _ = subjectTitle
#endif
        }
    }

    /// Планирует обновление только при изменении полезного состояния операции.
    func update(
        operationID: UUID,
        progress: OperationProgress
    ) {
        guard activeOperationID == operationID,
              finishedOperationID != operationID,
              shouldPublish(progress) else {
            return
        }

        lastPublishedProgress = progress
        let previousTask = lifecycleTail
        lifecycleTail = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self,
                  self.activeOperationID == operationID,
                  self.finishedOperationID != operationID else {
                return
            }

#if canImport(ActivityKit)
            guard #available(iOS 16.2, *),
                  self.activityOperationID == operationID,
                  let activity = self.activity else {
                return
            }

            await activity.update(
                self.makeActivityContent(for: progress)
            )
#else
            _ = progress
#endif
        }
    }

    /// Публикует итог и завершает Activity ровно один раз.
    /// Проверка operationID не допускает поздний итог старой операции в новой Activity.
    func finish(
        operationID: UUID,
        progress: OperationProgress
    ) {
        guard activeOperationID == operationID,
              finishedOperationID != operationID else {
            return
        }

        finishedOperationID = operationID
        lastPublishedProgress = progress
        let previousTask = lifecycleTail
        lifecycleTail = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self else { return }

#if canImport(ActivityKit)
            if self.activityOperationID == operationID,
               let activity = self.activity {
                self.activity = nil
                self.activityOperationID = nil
                await self.endActivity(
                    activity,
                    progress: progress,
                    dismissalPolicy: .default
                )
            }
#else
            _ = progress
#endif

            if self.activeOperationID == operationID {
                self.activeOperationID = nil
                self.finishedOperationID = nil
                self.lastPublishedProgress = nil
            }
        }
    }

    /// Проверяет, даст ли снимок полезное изменение для пользователя.
    /// Системный таймер продолжает работать самостоятельно между такими обновлениями.
    private func shouldPublish(_ progress: OperationProgress) -> Bool {
        guard let lastPublishedProgress else { return true }

        guard progress.completedUnits != lastPublishedProgress.completedUnits
                || progress.totalUnits != lastPublishedProgress.totalUnits
                || progress.phase != lastPublishedProgress.phase else {
            switch (lastPublishedProgress.estimatedEndDate, progress.estimatedEndDate) {
            case let (oldDate?, newDate?):
                return abs(newDate.timeIntervalSince(oldDate))
                    >= Self.estimatedEndDateUpdateThreshold
            case (nil, nil):
                return false
            case (_, _):
                return true
            }
        }

        return true
    }

#if canImport(ActivityKit)
    /// Завершает Activity, оставшиеся после перезапуска или некорректного состояния.
    @available(iOS 16.2, *)
    private func finishExistingActivities(
        with progress: OperationProgress
    ) async {
        if let activity,
           activityOperationID != activeOperationID {
            await endActivity(
                activity,
                progress: progress,
                dismissalPolicy: .immediate
            )
            self.activity = nil
            activityOperationID = nil
        }

        for existingActivity in Activity<ProgressActivityAttributes>.activities {
            await endActivity(
                existingActivity,
                progress: progress,
                dismissalPolicy: .immediate
            )
        }
    }

    /// Создаёт Activity через доступный на текущей версии iOS API.
    @available(iOS 16.2, *)
    private func requestActivity(
        attributes: ProgressActivityAttributes,
        progress: OperationProgress
    ) throws -> Activity<ProgressActivityAttributes> {
        return try Activity.request(
            attributes: attributes,
            content: makeActivityContent(for: progress),
            pushType: nil
        )
    }

    /// Завершает Activity через API поддерживаемой версией ActivityKit.
    @available(iOS 16.2, *)
    private func endActivity(
        _ activity: Activity<ProgressActivityAttributes>,
        progress: OperationProgress,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async {
        await activity.end(
            makeActivityContent(for: progress),
            dismissalPolicy: dismissalPolicy
        )
    }

    /// Собирает динамическое состояние Activity из универсального снимка.
    @available(iOS 16.2, *)
    private func makeContentState(
        for progress: OperationProgress
    ) -> ProgressActivityAttributes.ContentState {
        ProgressActivityAttributes.ContentState(
            completedUnits: progress.completedUnits,
            totalUnits: progress.totalUnits,
            estimatedEndDate: progress.estimatedEndDate,
            phase: progress.phase
        )
    }

    /// Создаёт содержимое с датой, которую системный таймер показывает без ручного Timer.
    @available(iOS 16.2, *)
    private func makeActivityContent(
        for progress: OperationProgress
    ) -> ActivityContent<ProgressActivityAttributes.ContentState> {
        ActivityContent(
            state: makeContentState(for: progress),
            staleDate: nil
        )
    }
#endif
}
