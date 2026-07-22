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

/// Хранит состояние iCloud одной строки без подписки на состояние всего списка.
@MainActor
final class CloudTrackAvailabilityRowStateStore: ObservableObject {

    /// Последнее достоверно определённое состояние iCloud-файла.
    @Published private(set) var state: CloudTrackAvailabilityState?

    init(
        state: CloudTrackAvailabilityState?
    ) {
        self.state = state
    }

    /// Публикует изменение только для строки, чьё состояние действительно поменялось.
    func apply(
        _ state: CloudTrackAvailabilityState?
    ) {
        guard self.state != state else {
            return
        }

        self.state = state
    }
}

/// Хранит состояния видимых строк и обновляет iCloud-файлы одной общей задачей.
@MainActor
final class CloudTrackAvailabilityController {

    // MARK: - Состояние

    /// Последнее достоверно определённое iCloud-состояние по идентификатору трека.
    private var statesByTrackId: [UUID: CloudTrackAvailabilityState] = [:]
    /// Observable-состояния создаются только для строк, созданных List.
    private var stateStoresByTrackId: [UUID: CloudTrackAvailabilityRowStateStore] = [:]

    // MARK: - Зависимости

    /// Компонент, который изолированно читает URL resource values и отправляет системный запрос загрузки.
    private let manager: any CloudTrackAvailabilityManaging

    // MARK: - Наблюдение

    /// Идентификаторы треков, видимых на текущем экране фонотеки.
    private var trackedTrackIds = Set<UUID>()
    /// Треки, для которых уже выполнялась первоначальная проверка resource values.
    private var initiallyCheckedTrackIds = Set<UUID>()
    /// Единственная задача, которая обновляет все iCloud-файлы видимой области.
    private var observationTask: Task<Void, Never>?
    /// Идентификатор актуального запуска общей задачи наблюдения.
    private var observationToken: UUID?
    /// Показывает, что общая задача ожидает следующего периодического обновления.
    private var isWaitingForNextRefresh = false
    /// Запрашивает немедленный повторный проход, если набор треков изменился во время обновления.
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

    /// Возвращает точечное observable-состояние конкретной строки.
    func stateStore(
        for trackId: UUID
    ) -> CloudTrackAvailabilityRowStateStore {
        if let existingStore = stateStoresByTrackId[trackId] {
            return existingStore
        }

        let stateStore = CloudTrackAvailabilityRowStateStore(
            state: statesByTrackId[trackId]
        )
        stateStoresByTrackId[trackId] = stateStore
        return stateStore
    }

    /// Синхронизирует набор видимых треков, подготовленный экранным контроллером.
    func updateTrackedTrackIds(
        _ trackIds: [UUID]
    ) {
        let updatedTrackIds = Set(trackIds)
        guard trackedTrackIds != updatedTrackIds else {
            return
        }

        trackedTrackIds = updatedTrackIds

        guard trackedTrackIds.isEmpty == false else {
            cancelObservation()
            return
        }

        requestImmediateRefresh()
    }

    /// Сбрасывает экранное наблюдение при уходе с экрана фонотеки.
    func stopTracking() {
        for stateStore in stateStoresByTrackId.values {
            stateStore.apply(nil)
        }

        trackedTrackIds.removeAll()
        initiallyCheckedTrackIds.removeAll()
        statesByTrackId.removeAll()
        stateStoresByTrackId.removeAll()
        cancelObservation()
    }

    /// Повторно запрашивает загрузку iCloud-файла после нажатия кнопки ошибки.
    func retryDownloading(
        trackId: UUID
    ) async {
        let state = await manager.retryDownloading(trackId: trackId)

        guard trackedTrackIds.contains(trackId) else {
            return
        }

        apply(state: state, for: trackId)

        requestImmediateRefresh()
    }

    // MARK: - Общая задача наблюдения

    /// Запускает или ускоряет общий проход проверки без таймеров на уровне строк.
    private func requestImmediateRefresh() {
        guard trackedTrackIds.isEmpty == false else {
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

    /// Применяет только результаты треков, оставшихся видимыми к моменту завершения проверки.
    private func apply(
        refreshedStates: [UUID: CloudTrackAvailabilityState],
        for trackIds: [UUID]
    ) {
        for trackId in trackIds where trackedTrackIds.contains(trackId) {
            initiallyCheckedTrackIds.insert(trackId)
            apply(state: refreshedStates[trackId], for: trackId)
        }
    }

    /// Сохраняет состояние и публикует его только созданной строке этого трека.
    private func apply(
        state: CloudTrackAvailabilityState?,
        for trackId: UUID
    ) {
        let currentState = statesByTrackId[trackId]
        guard currentState != state else {
            return
        }

        if let state {
            statesByTrackId[trackId] = state
        } else {
            statesByTrackId.removeValue(forKey: trackId)
        }

        stateStoresByTrackId[trackId]?.apply(state)
    }

    /// Проверяет, остался ли хотя бы один видимый iCloud-файл, состояние которого нужно обновлять.
    private var requiresPeriodicRefresh: Bool {
        trackedTrackIds.contains { trackId in
            statesByTrackId[trackId]?.requiresPeriodicRefresh == true
        }
    }

    /// Возвращает новые строки и только те iCloud-файлы, которые ещё не стали локальными.
    private var trackIdsForRefresh: [UUID] {
        trackedTrackIds.filter { trackId in
            initiallyCheckedTrackIds.contains(trackId) == false ||
            statesByTrackId[trackId]?.requiresPeriodicRefresh == true
        }
    }
}

/// Собирает видимые строки экрана и передаёт их одной пакетной проверке iCloud.
@MainActor
final class LibraryCloudAvailabilityScreenController {

    // MARK: - Зависимости

    /// Общий контроллер проверки iCloud-состояний только для видимой области.
    private let availabilityController: CloudTrackAvailabilityController

    // MARK: - Состояние

    /// Треки, видимость которых уже сообщила строка List.
    private var visibleTrackIds = Set<UUID>()
    /// Единственная короткая задержка собирает всплеск onAppear/onDisappear в один пакет.
    private var visibilityRefreshTask: Task<Void, Never>?
    /// Не принимает запоздалые события строк после ухода экрана.
    private var isScreenVisible = false

    // MARK: - Init

    init() {
        availabilityController = CloudTrackAvailabilityController()
    }

    init(
        availabilityController: CloudTrackAvailabilityController
    ) {
        self.availabilityController = availabilityController
    }

    deinit {
        visibilityRefreshTask?.cancel()
    }

    // MARK: - Публичный API

    /// Возвращает точечное observable-состояние строки.
    func stateStore(
        for trackId: UUID
    ) -> CloudTrackAvailabilityRowStateStore {
        availabilityController.stateStore(for: trackId)
    }

    /// Включает передачу видимых строк при появлении экрана.
    func screenDidAppear() {
        isScreenVisible = true
        scheduleVisibleTracksRefresh()
    }

    /// Добавляет строку к видимой области без обращения к файловой системе из View.
    func rowDidAppear(
        trackId: UUID
    ) {
        guard visibleTrackIds.insert(trackId).inserted else {
            return
        }

        scheduleVisibleTracksRefresh()
    }

    /// Убирает строку из видимой области без сброса уже определённого состояния трека.
    func rowDidDisappear(
        trackId: UUID
    ) {
        guard visibleTrackIds.remove(trackId) != nil else {
            return
        }

        scheduleVisibleTracksRefresh()
    }

    /// Передаёт повторную загрузку в общий контроллер iCloud.
    func retryDownloading(
        trackId: UUID
    ) async {
        await availabilityController.retryDownloading(trackId: trackId)
    }

    /// Останавливает экранное наблюдение и освобождает состояния ушедшего списка.
    func screenDidDisappear() {
        isScreenVisible = false
        visibleTrackIds.removeAll()
        visibilityRefreshTask?.cancel()
        visibilityRefreshTask = nil
        availabilityController.stopTracking()
    }

    // MARK: - Пакетирование видимости

    /// Планирует один короткий проход после серии изменений видимости при прокрутке.
    private func scheduleVisibleTracksRefresh() {
        guard isScreenVisible,
              visibilityRefreshTask == nil else {
            return
        }

        visibilityRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 80_000_000)
            } catch {
                self?.visibilityRefreshTask = nil
                return
            }

            guard let self,
                  Task.isCancelled == false else {
                return
            }

            self.visibilityRefreshTask = nil
            self.availabilityController.updateTrackedTrackIds(
                Array(self.visibleTrackIds)
            )
        }
    }
}
