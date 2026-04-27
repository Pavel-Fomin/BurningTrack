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
    ) async -> TrackUpdateEvent? {

        // Получаем актуальный URL трека через существующий bookmark pipeline.
        guard let url = await BookmarkResolver.url(forTrack: trackId) else { return nil }

        // Сбрасываем runtime-кэши перед повторной сборкой snapshot.
        invalidateRuntimeCaches(
            forTrackId: trackId,
            url: url,
            previousURL: previousURL
        )

        // Пересобираем каноничный snapshot трека.
        guard let snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId) else {
            return nil
        }

        // Сохраняем новый snapshot в централизованное runtime-хранилище.
        TrackRuntimeStore.shared.storeSnapshot(snapshot)

        // Собираем единое событие обновления.
        let updateEvent = TrackUpdateEvent(
            trackId: trackId,
            reason: reason,
            changedFields: changedFields,
            snapshot: snapshot
        )

        // Публикуем событие для подписчиков.
        publishTrackUpdateEvent(updateEvent)

        return updateEvent
    }

    // MARK: - Invalidate

    /// Инвалидирует runtime-кэши, связанные с треком.
    ///
    /// - Parameters:
    ///   - trackId: Идентификатор трека
    ///   - url: Актуальный URL трека
    ///   - previousURL: Предыдущий URL трека, если файл был перемещён или переименован
    private func invalidateRuntimeCaches(
        forTrackId trackId: UUID,
        url: URL,
        previousURL: URL?
    ) {

        // Сбрасываем raw metadata cache по актуальному URL.
        TrackMetadataCacheManager.shared.invalidate(url: url)

        // Если путь файла изменился, сбрасываем raw metadata cache и по старому URL.
        if let previousURL, previousURL != url {
            TrackMetadataCacheManager.shared.invalidate(url: previousURL)
        }

        // Сбрасываем производный image-cache artwork.
        ArtworkProvider.shared.invalidate(trackId: trackId)

        // Удаляем старый snapshot из централизованного runtime store.
        TrackRuntimeStore.shared.removeSnapshot(forTrackId: trackId)
    }

    // MARK: - Publish

    /// Публикует единое событие обновления трека.
    ///
    /// - Parameter updateEvent: Готовое событие обновления
    private func publishTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        NotificationCenter.default.post(name: .trackDidUpdate, object: updateEvent)
    }
}
