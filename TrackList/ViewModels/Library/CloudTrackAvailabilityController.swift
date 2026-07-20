//
//  CloudTrackAvailabilityController.swift
//  TrackList
//
//  Контроллер наблюдения за iCloud-состояниями видимых строк фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Combine
import Foundation

/// Хранит состояния видимых строк и обновляет iCloud-файлы одной общей задачей.
@MainActor
final class CloudTrackAvailabilityController: ObservableObject {

    // MARK: - Состояние

    /// Последнее достоверно определённое iCloud-состояние по идентификатору трека.
    @Published private(set) var statesByTrackId: [UUID: CloudTrackAvailabilityState] = [:]

    // MARK: - Зависимости

    /// Компонент, который изолированно читает URL resource values и отправляет системный запрос загрузки.
    private let manager: any CloudTrackAvailabilityManaging

    // MARK: - Наблюдение

    /// Идентификаторы строк, которые сейчас находятся на экране и нуждаются в актуальном состоянии.
    private var observedTrackIds = Set<UUID>()
    /// Строки, для которых уже выполнялась первоначальная проверка resource values.
    private var initiallyCheckedTrackIds = Set<UUID>()
    /// Единственная задача, которая обновляет все наблюдаемые iCloud-файлы.
    private var observationTask: Task<Void, Never>?
    /// Идентификатор актуального запуска общей задачи наблюдения.
    private var observationToken: UUID?
    /// Показывает, что общая задача ожидает следующего периодического обновления.
    private var isWaitingForNextRefresh = false
    /// Запрашивает немедленный повторный проход, если видимая строка появилась во время обновления.
    private var needsImmediateRefresh = false

    // MARK: - Init

    init(
        manager: any CloudTrackAvailabilityManaging = CloudTrackAvailabilityManager.shared
    ) {
        self.manager = manager
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Публичный API

    /// Возвращает последнее определённое состояние iCloud-файла для построения строки.
    func state(
        for trackId: UUID
    ) -> CloudTrackAvailabilityState? {
        statesByTrackId[trackId]
    }

    /// Начинает наблюдение за строкой при её появлении без дублирования параллельных задач.
    func beginObserving(
        trackId: UUID
    ) {
        guard observedTrackIds.insert(trackId).inserted else {
            return
        }

        requestImmediateRefresh()
    }

    /// Прекращает наблюдение за строкой при её исчезновении.
    func stopObserving(
        trackId: UUID
    ) {
        guard observedTrackIds.remove(trackId) != nil else {
            return
        }

        statesByTrackId.removeValue(forKey: trackId)
        initiallyCheckedTrackIds.remove(trackId)

        if observedTrackIds.isEmpty {
            cancelObservation()
        }
    }

    /// Повторно запрашивает загрузку iCloud-файла после нажатия кнопки ошибки.
    func retryDownloading(
        trackId: UUID
    ) async {
        let state = await manager.retryDownloading(trackId: trackId)

        guard observedTrackIds.contains(trackId) else {
            return
        }

        if let state {
            statesByTrackId[trackId] = state
        } else {
            statesByTrackId.removeValue(forKey: trackId)
        }

        requestImmediateRefresh()
    }

    // MARK: - Общая задача наблюдения

    /// Запускает или ускоряет общий проход проверки без таймеров на уровне строк.
    private func requestImmediateRefresh() {
        guard observedTrackIds.isEmpty == false else {
            return
        }

        guard observationTask != nil else {
            startObservation()
            return
        }

        needsImmediateRefresh = true

        // Если задача спит между проходами, перезапускаем только одну общую задачу для немедленной проверки.
        if isWaitingForNextRefresh {
            startObservation()
        }
    }

    /// Создаёт единственную актуальную задачу периодического наблюдения.
    private func startObservation() {
        observationTask?.cancel()

        let token = UUID()
        observationToken = token
        isWaitingForNextRefresh = false
        needsImmediateRefresh = false
        observationTask = Task { [weak self] in
            await self?.observeStates(using: token)
        }
    }

    /// Останавливает общую задачу, когда на экране не осталось строк для наблюдения.
    private func cancelObservation() {
        observationTask?.cancel()
        observationTask = nil
        observationToken = nil
        isWaitingForNextRefresh = false
        needsImmediateRefresh = false
    }

    /// Обновляет все видимые iCloud-файлы пакетно до перехода каждого из них в локальное состояние.
    private func observeStates(
        using token: UUID
    ) async {
        defer {
            if observationToken == token {
                observationTask = nil
                observationToken = nil
                isWaitingForNextRefresh = false
            }
        }

        while Task.isCancelled == false {
            let trackIds = trackIdsForRefresh
            guard trackIds.isEmpty == false else {
                return
            }

            let refreshedStates = await manager.availabilityStates(for: trackIds)
            guard Task.isCancelled == false,
                  observationToken == token else {
                return
            }

            apply(
                refreshedStates: refreshedStates,
                for: trackIds
            )

            if needsImmediateRefresh {
                needsImmediateRefresh = false
                continue
            }

            guard requiresPeriodicRefresh else {
                return
            }

            isWaitingForNextRefresh = true

            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard observationToken == token else {
                return
            }

            isWaitingForNextRefresh = false
        }
    }

    /// Применяет только результаты треков, которые остались видимыми к моменту завершения проверки.
    private func apply(
        refreshedStates: [UUID: CloudTrackAvailabilityState],
        for trackIds: [UUID]
    ) {
        for trackId in trackIds where observedTrackIds.contains(trackId) {
            initiallyCheckedTrackIds.insert(trackId)

            if let state = refreshedStates[trackId] {
                statesByTrackId[trackId] = state
            } else {
                statesByTrackId.removeValue(forKey: trackId)
            }
        }
    }

    /// Проверяет, остался ли хотя бы один видимый iCloud-файл, состояние которого нужно обновлять.
    private var requiresPeriodicRefresh: Bool {
        observedTrackIds.contains { trackId in
            statesByTrackId[trackId]?.requiresPeriodicRefresh == true
        }
    }

    /// Возвращает новые строки и только те iCloud-файлы, которые ещё не стали локальными.
    private var trackIdsForRefresh: [UUID] {
        observedTrackIds.filter { trackId in
            initiallyCheckedTrackIds.contains(trackId) == false ||
            statesByTrackId[trackId]?.requiresPeriodicRefresh == true
        }
    }
}
