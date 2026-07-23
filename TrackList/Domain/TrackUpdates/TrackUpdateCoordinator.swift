//
//  TrackUpdateCoordinator.swift
//  TrackList
//
//  Центральный coordinator единого контракта обновления трека.
//  Роль:
// - инвалидирует runtime-кэши после изменения трека
// - пересобирает каноничный TrackRuntimeSnapshot
// - сохраняет snapshot в TrackRuntimeStore
// - публикует единое событие обновления
//
// Важно:
// - сам не пишет теги в файл
// - сам не читает UI
// - работает только как post-update orchestration слой
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

/// Ошибка подготовки одного элемента пакетного post-update pipeline.
/// Нужна вызывающему batch-сценарию, чтобы показать ошибку именно у трека без публикации ложного batch-события.
enum TrackUpdateCoordinatorError: Error {
    case updateFailed(trackId: UUID, underlying: Error)
}

final class TrackUpdateCoordinator {

    // MARK: - Singleton

    static let shared = TrackUpdateCoordinator()  /// Общий экземпляр coordinator обновления трека

    // MARK: - Init

    private init() {}

    // MARK: - Handle update

    /// Выполняет полный post-update pipeline для одного трека.
    ///
    /// Pipeline:
    /// - получает URL трека
    /// - инвалидирует runtime-кэши
    /// - пересобирает каноничный snapshot
    /// - сохраняет snapshot в runtime store
    /// - публикует TrackUpdateEvent
    ///
    /// - Parameters:
    ///   - trackId: Идентификатор трека
    ///   - reason: Причина обновления
    ///   - changedFields: Набор изменённых полей
    /// - Returns: Готовое событие обновления или nil, если snapshot не удалось собрать
    func handleTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL? = nil
    ) async throws -> TrackUpdateEvent? {
        guard let updateEvent = try await makeTrackUpdateEvent(
            forTrackId: trackId,
            reason: reason,
            changedFields: changedFields,
            previousURL: previousURL
        ) else { return nil }

        // Публикуем событие только после успешного сохранения snapshot metadata в SQLite.
        await publishTrackUpdateEvent(updateEvent)

        return updateEvent
    }

    /// Обновляет runtime-состояние для нескольких треков после файловых изменений.
    ///
    /// Метод не показывает toast. Он только:
    /// - сбрасывает cache;
    /// - пересобирает runtime snapshot;
    /// - публикует track update event.
    func handleTrackUpdates(_ updates: [TrackUpdateRequest]) async throws -> [TrackUpdateEvent] {
        var events: [TrackUpdateEvent] = []

        for update in updates {
            do {
                if let event = try await makeTrackUpdateEvent(
                    forTrackId: update.trackId,
                    reason: .fileRenamed,
                    changedFields: [.fileName],
                    previousURL: update.previousURL
                ) {
                    events.append(event)
                }
            } catch {
                // Batch-сценарий получает trackId ошибки и не публикует подготовленные события до полного успеха.
                throw TrackUpdateCoordinatorError.updateFailed(
                    trackId: update.trackId,
                    underlying: error
                )
            }
        }

        // Пакетное событие публикуется только для полностью подготовленного набора успешно сохранённых snapshot.
        await publishTrackBatchUpdateEvent(events)

        return events
    }

    /// Собирает событие обновления трека без публикации NotificationCenter.
    private func makeTrackUpdateEvent(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL? = nil
    ) async throws -> TrackUpdateEvent? {

        // Получаем актуальный URL трека через существующий bookmark pipeline.
        guard let url = await BookmarkResolver.url(forTrack: trackId) else { return nil }

        // Сбрасываем runtime-кэши перед повторной сборкой snapshot.
        await invalidateRuntimeCaches(
            forTrackId: trackId,
            url: url,
            previousURL: previousURL,
            changedFields: changedFields
        )

        // Пересобираем каноничный snapshot трека.
        guard let snapshot = try await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId) else {
            return nil
        }

        // Сохраняем новый snapshot в централизованное runtime-хранилище.
        await TrackRuntimeStore.shared.storeSnapshot(snapshot)

        return TrackUpdateEvent(
            trackId: trackId,
            reason: reason,
            changedFields: changedFields,
            snapshot: snapshot
        )
    }

    // MARK: - Invalidate

    /// Инвалидирует runtime-кэши, связанные с треком.
    ///
    /// - Parameters:
    ///   - trackId: Идентификатор трека
    ///   - url: Актуальный URL трека
    ///   - previousURL: Предыдущий URL трека, если файл был перемещён или переименован
    ///   - changedFields: Поля, реально изменённые операцией записи
    private func invalidateRuntimeCaches(
        forTrackId trackId: UUID,
        url: URL,
        previousURL: URL?,
        changedFields: Set<TrackChangedField>
    ) async {

        // Сбрасываем raw metadata cache по актуальному URL.
        await TrackMetadataCacheManager.shared.invalidate(url: url)

        // Если путь файла изменился, сбрасываем raw metadata cache и по старому URL.
        if let previousURL, previousURL != url {
            await TrackMetadataCacheManager.shared.invalidate(url: previousURL)
        }

        // Производный image-cache сбрасываем только после фактического изменения обложки.
        // Переименование и изменение текстовых тегов не должны повторно декодировать повреждённый artwork.
        if changedFields.contains(.artworkData) {
            await ArtworkProvider.shared.invalidate(trackId: trackId)
        }

        // Удаляем старый snapshot из централизованного runtime store.
        await TrackRuntimeStore.shared.removeSnapshot(forTrackId: trackId)
    }

    // MARK: - Publish

    /// Публикует единое событие обновления трека.
    ///
    /// - Parameter updateEvent: Готовое событие обновления
    @MainActor
    private func publishTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        NotificationCenter.default.post(name: .trackDidUpdate, object: updateEvent)
    }

    /// Публикует пакетное событие обновления треков.
    ///
    /// - Parameter updateEvents: Готовые события обновления треков
    @MainActor
    private func publishTrackBatchUpdateEvent(_ updateEvents: [TrackUpdateEvent]) {
        guard !updateEvents.isEmpty else { return }

        NotificationCenter.default.post(
            name: .trackBatchDidUpdate,
            object: nil,
            userInfo: ["events": updateEvents]
        )
    }
}
