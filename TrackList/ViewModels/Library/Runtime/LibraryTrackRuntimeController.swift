//
//  LibraryTrackRuntimeController.swift
//  TrackList
//
//  Контроллер runtime snapshot-ов фонотеки.
//  Отделяет runtime pipeline от LibraryTracksViewModel.
//
//  Created by Pavel Fomin on 21.06.2026.
//

import Combine
import Foundation

/// Управляет runtime snapshot-ами, которые нужны модулю фонотеки.
///
/// Отвечает только за:
/// - хранение snapshot-ов по trackId;
/// - загрузку snapshot из TrackRuntimeStore или TrackRuntimeSnapshotBuilder;
/// - сохранение собранного snapshot в TrackRuntimeStore;
/// - применение готовых TrackUpdateEvent к локальному состоянию.
///
/// Не знает про UI, View, batch-сценарии, NotificationCenter, Player и badges.
@MainActor
final class LibraryTrackRuntimeController: ObservableObject {

    private struct SnapshotGeneration: Equatable, Sendable {
        let global: UInt64
        let track: UInt64
    }

    private struct SnapshotRequestToken: Equatable, Sendable {
        let trackId: UUID
        let generation: SnapshotGeneration
    }

    private struct SnapshotLoad {
        let token: SnapshotRequestToken
        var waiters: [CheckedContinuation<TrackRuntimeSnapshot?, Never>]
    }

    // MARK: - Состояние

    /// Локальная проекция snapshot-ов для фонотеки; общий `TrackRuntimeStore` остаётся источником уже подготовленных данных между feature.
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]
    /// Builder и store явно передаются при сборке feature и могут заменяться тестовыми дублёрами.
    private let runtimeSnapshotStore: any TrackRuntimeSnapshotStoring
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// Глобальная инвалидация отделяет clear всех снимков от точечных TrackUpdateEvent.
    private var globalGeneration: UInt64 = 0
    /// Поколение одного трека не влияет на незавершённую сборку другого physical track ID.
    private var generationByTrackId: [UUID: UInt64] = [:]
    /// Token связывает состояние загрузки с конкретным запуском, а не только с trackId.
    private var loadingByTrackId: [UUID: SnapshotLoad] = [:]

    // MARK: - Инициализация

    /// Рабочие зависимости передаются фабрикой, чтобы controller не разрешал
    /// application-wide singleton самостоятельно.
    init(
        runtimeSnapshotStore: any TrackRuntimeSnapshotStoring,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    ) {
        self.runtimeSnapshotStore = runtimeSnapshotStore
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
    }

    // MARK: - Публичное

    /// Возвращает runtime snapshot трека по его идентификатору.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: TrackRuntimeSnapshot или nil
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        guard snapshotsByTrackId[trackId] == nil,
              loadingByTrackId[trackId] == nil else {
            return
        }

        // Token захватывается до создания Task, поэтому clear или TrackUpdateEvent,
        // случившиеся до её старта, не превращают прежний запрос в новое поколение.
        let token = SnapshotRequestToken(
            trackId: trackId,
            generation: snapshotGeneration(for: trackId)
        )

        Task { [weak self] in
            guard let self else { return }

            _ = await self.loadSnapshotIfNeeded(for: trackId, token: token)
        }
    }

    // MARK: - Внутреннее

    /// Загружает runtime snapshot и возвращает результат сценариям, которым нужно дождаться metadata.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: Загруженный TrackRuntimeSnapshot или nil
    @discardableResult
    func loadSnapshotIfNeeded(for trackId: UUID) async -> TrackRuntimeSnapshot? {
        let token = SnapshotRequestToken(
            trackId: trackId,
            generation: snapshotGeneration(for: trackId)
        )

        return await loadSnapshotIfNeeded(for: trackId, token: token)
    }

    /// Продолжает запрос только пока захваченное поколение остаётся актуальным.
    private func loadSnapshotIfNeeded(
        for trackId: UUID,
        token: SnapshotRequestToken
    ) async -> TrackRuntimeSnapshot? {
        guard isCurrent(token) else {
            return nil
        }

        if let existingSnapshot = snapshotsByTrackId[trackId] {
            return existingSnapshot
        }

        if var load = loadingByTrackId[trackId] {
            return await withCheckedContinuation { continuation in
            // Continuation присоединяется к конкретному token текущей загрузки.
                // После инвалидации эта загрузка завершится nil, а новый token не затронут.
                load.waiters.append(continuation)
                loadingByTrackId[trackId] = load
            }
        }

        loadingByTrackId[trackId] = SnapshotLoad(token: token, waiters: [])

        let snapshot: TrackRuntimeSnapshot?

        // Сначала используем общий runtime store как быстрый источник уже собранного snapshot.
        if let storedSnapshot = runtimeSnapshotStore.snapshot(forTrackId: trackId) {
            snapshot = storedSnapshot
        } else {
            snapshot = try? await runtimeSnapshotBuilder.buildSnapshot(forTrackId: trackId)
        }

        // Поколение проверяется до store: устаревшая сборка не должна загрязнить общий кэш,
        // даже если его локальный snapshot позже был бы отброшен.
        guard Task.isCancelled == false,
              isCurrent(token) else {
            completeSnapshotLoading(token: token, snapshot: nil)
            return nil
        }

        if let snapshot {
            snapshotsByTrackId[trackId] = snapshot
            if runtimeSnapshotStore.snapshot(forTrackId: trackId) == nil {
                runtimeSnapshotStore.storeSnapshot(snapshot)
            }
        }

        completeSnapshotLoading(
            token: token,
            snapshot: snapshot
        )

        return snapshot
    }

    /// Завершает загрузку только при совпадении token, поэтому старое завершение не может
    /// снять состояние загрузки нового поколения того же trackId.
    private func completeSnapshotLoading(
        token: SnapshotRequestToken,
        snapshot: TrackRuntimeSnapshot?
    ) {
        guard let load = loadingByTrackId[token.trackId], load.token == token else {
            return
        }

        loadingByTrackId[token.trackId] = nil
        for waiter in load.waiters {
            waiter.resume(returning: snapshot)
        }
    }

    /// Применяет готовые события обновления треков к локальному состоянию snapshot-ов.
    ///
    /// - Parameter events: События с уже собранными runtime snapshot
    func applyTrackUpdateEvents(_ events: [TrackUpdateEvent]) {
        guard !events.isEmpty else { return }

        var updatedSnapshots = snapshotsByTrackId

        for event in events {
            // Новый event является достоверным результатом и завершает ожидания старого
            // поколения nil до того, как новый snapshot станет видимым controller-у.
            invalidateSnapshotGeneration(for: event.trackId)
            updatedSnapshots[event.trackId] = event.snapshot
        }

        snapshotsByTrackId = updatedSnapshots
    }

    /// Очищает локальные snapshot-ы фонотеки.
    func clearSnapshots() {
        // Общее поколение инвалидирует все незавершённые сборки; их завершение не сможет
        // записать устаревшие данные ни локально, ни в TrackRuntimeStore.
        globalGeneration &+= 1
        generationByTrackId.removeAll()
        snapshotsByTrackId.removeAll()

        let staleLoads = loadingByTrackId.values
        loadingByTrackId.removeAll()
        for load in staleLoads {
            for waiter in load.waiters {
                waiter.resume(returning: nil)
            }
        }
    }

    private func snapshotGeneration(for trackId: UUID) -> SnapshotGeneration {
        SnapshotGeneration(
            global: globalGeneration,
            track: generationByTrackId[trackId, default: 0]
        )
    }

    private func isCurrent(_ token: SnapshotRequestToken) -> Bool {
        token.generation == snapshotGeneration(for: token.trackId)
    }

    private func invalidateSnapshotGeneration(for trackId: UUID) {
        generationByTrackId[trackId, default: 0] &+= 1

        guard let staleLoad = loadingByTrackId.removeValue(forKey: trackId) else {
            return
        }

        for waiter in staleLoad.waiters {
            waiter.resume(returning: nil)
        }
    }
}
