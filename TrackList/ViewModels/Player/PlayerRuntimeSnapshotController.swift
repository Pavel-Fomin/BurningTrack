//
//  PlayerRuntimeSnapshotController.swift
//  TrackList
//
//  Контроллер runtime snapshot-ов, нужных плееру.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation
import CoreGraphics

/// Управляет runtime snapshot-ами, нужными плееру.
///
/// Отвечает только за:
/// - хранение snapshot-ов по trackId;
/// - загрузку snapshot из TrackRuntimeStore или TrackRuntimeSnapshotBuilder;
/// - сборку artwork для Now Playing;
/// - применение TrackUpdateEvent к локальному состоянию.
///
/// Не управляет AVPlayer.
/// Не обновляет MiniPlayer напрямую.
/// Не применяет NowPlayingInfo напрямую.
@MainActor
final class PlayerRuntimeSnapshotController {

    private struct SnapshotGeneration: Equatable, Sendable {
        let global: UInt64
        let track: UInt64
    }

    private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]
    private(set) var nowPlayingArtworkByTrackId: [UUID: CGImage] = [:]
    /// Общий store передаётся слоем сборки и остаётся быстрым источником уже готовых данных.
    private let runtimeSnapshotStore: any TrackRuntimeSnapshotStoring
    /// Builder внедряется для управляемой проверки позднего асинхронного завершения.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// Provider обложек разделяет рабочий кэш, но не владеет состоянием controller-а.
    private let artworkProvider: any ArtworkImageProviding
    /// Полная очистка инвалидирует все ранее захваченные поколения одним счётчиком.
    private var globalGeneration: UInt64 = 0
    /// Точечный TrackUpdateEvent затрагивает только свой physical track ID.
    private var generationByTrackId: [UUID: UInt64] = [:]

    /// Рабочие зависимости передаются корнем композиции, чтобы controller не разрешал
    /// application-wide singleton самостоятельно.
    init(
        runtimeSnapshotStore: any TrackRuntimeSnapshotStoring,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        artworkProvider: any ArtworkImageProviding
    ) {
        self.runtimeSnapshotStore = runtimeSnapshotStore
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.artworkProvider = artworkProvider
    }

    /// Возвращает runtime snapshot по trackId.
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    /// Возвращает artwork для Now Playing по trackId.
    func nowPlayingArtwork(for trackId: UUID) -> CGImage? {
        nowPlayingArtworkByTrackId[trackId]
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// Возвращает trackId, если состояние контроллера изменилось.
    func requestSnapshotIfNeeded(for trackId: UUID) async -> UUID? {

        if snapshotsByTrackId[trackId] != nil {
            return nil
        }

        // Поколение фиксируется до ожидания. TrackUpdateEvent или clear во время сборки
        // делают поздний результат устаревшим, поэтому он больше не меняет controller.
        let generation = snapshotGeneration(for: trackId)

        // 1. Получаем snapshot из store или собираем через builder.
        let snapshot: TrackRuntimeSnapshot?

        if let storedSnapshot = runtimeSnapshotStore.snapshot(forTrackId: trackId) {
            snapshot = storedSnapshot
        } else {
            snapshot = try? await runtimeSnapshotBuilder.buildSnapshot(forTrackId: trackId)
        }

        guard let snapshot,
              Task.isCancelled == false,
              isCurrent(generation, for: trackId) else {
            return nil
        }

        snapshotsByTrackId[trackId] = snapshot

        return trackId
    }

    /// Применяет событие обновления трека к локальному состоянию.
    func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) -> UUID {
        applyTrackUpdateEvents([updateEvent]).first ?? updateEvent.trackId
    }

    /// Применяет все подтверждённые snapshot batch-операции до одной следующей presentation-публикации owner-а.
    func applyTrackUpdateEvents(_ updateEvents: [TrackUpdateEvent]) -> Set<UUID> {
        var changedTrackIds: Set<UUID> = []

        for updateEvent in updateEvents {
            let trackId = updateEvent.trackId

            // TrackUpdateEvent несёт более новый достоверный snapshot и инвалидирует
            // незавершённую сборку только этого трека до записи нового состояния.
            invalidateSnapshotGeneration(for: trackId)

            // Обновляем snapshot и сбрасываем связанную Now Playing artwork.
            snapshotsByTrackId[trackId] = updateEvent.snapshot
            nowPlayingArtworkByTrackId[trackId] = nil
            changedTrackIds.insert(trackId)
        }

        return changedTrackIds
    }

    /// Асинхронно запрашивает большую обложку через общую подсистему подготовки.
    func requestNowPlayingArtworkIfNeeded(
        for trackId: UUID,
        artworkData: Data?,
        sourceIdentifier: ArtworkSourceIdentifier?,
        revision: Date?
    ) async -> UUID? {
        guard nowPlayingArtworkByTrackId[trackId] == nil else { return nil }
        guard let sourceIdentifier else { return nil }

        // Artwork использует то же поколение, что и snapshot, чтобы clear без revision
        // не позволял позднему результату подготовки изображения воскресить удалённую обложку.
        let generation = snapshotGeneration(for: trackId)

        let image = await artworkProvider.image(
            for: ArtworkRequest(
                trackId: trackId,
                artworkData: artworkData,
                purpose: .nowPlaying,
                sourceIdentifier: sourceIdentifier,
                revision: revision
            )
        )
        guard !Task.isCancelled,
              isCurrent(generation, for: trackId),
              let cgImage = image?.cgImage else {
            return nil
        }

        // Snapshot мог обновиться, пока общая очередь готовила прежнюю ревизию.
        if let revision,
           snapshotsByTrackId[trackId]?.updatedAt != revision {
            return nil
        }

        nowPlayingArtworkByTrackId[trackId] = cgImage
        return trackId
    }

    /// Очищает все snapshot-данные.
    func clear() {
        // Общее поколение инвалидирует все ранее начатые запросы snapshot и artwork.
        globalGeneration &+= 1
        generationByTrackId.removeAll()
        snapshotsByTrackId.removeAll()
        nowPlayingArtworkByTrackId.removeAll()
    }

    private func snapshotGeneration(for trackId: UUID) -> SnapshotGeneration {
        SnapshotGeneration(
            global: globalGeneration,
            track: generationByTrackId[trackId, default: 0]
        )
    }

    private func isCurrent(_ generation: SnapshotGeneration, for trackId: UUID) -> Bool {
        generation == snapshotGeneration(for: trackId)
    }

    private func invalidateSnapshotGeneration(for trackId: UUID) {
        generationByTrackId[trackId, default: 0] &+= 1
    }
}
