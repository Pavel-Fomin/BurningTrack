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

    private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]
    private(set) var nowPlayingArtworkByTrackId: [UUID: CGImage] = [:]

    /// Позволяет создавать контроллер как зависимость по умолчанию в init PlayerViewModel.
    nonisolated init() {}

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

        // 1. Получаем snapshot из store или собираем через builder.
        let snapshot: TrackRuntimeSnapshot?

        if let storedSnapshot = TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
            snapshot = storedSnapshot
        } else {
            snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
        }

        guard let snapshot else {
            return nil
        }

        snapshotsByTrackId[trackId] = snapshot

        // 2. Большой artwork для Lock Screen / Control Center (512px)
        // Берём СЫРЫЕ данные из snapshot и строим CGImage через ImageDownsampler.
        if let data = snapshot.artworkData,
           let nowPlayingCGImage = makeThumbnail(
            from: data,
            maxPixel: ArtworkPurposeSizes.maxPixel(for: .nowPlaying)
           ) {
            nowPlayingArtworkByTrackId[trackId] = nowPlayingCGImage
        }

        return trackId
    }

    /// Применяет событие обновления трека к локальному состоянию.
    func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) -> UUID {

        let trackId = updateEvent.trackId

        // 1. Обновляем локальный snapshot.
        snapshotsByTrackId[trackId] = updateEvent.snapshot

        // 2. Сбрасываем старую now playing обложку.
        nowPlayingArtworkByTrackId[trackId] = nil

        // 3. Пересобираем now playing artwork из нового snapshot.
        if let data = updateEvent.snapshot.artworkData,
           let cgImage = makeThumbnail(
            from: data,
            maxPixel: ArtworkPurposeSizes.maxPixel(for: .nowPlaying)
           ) {
            nowPlayingArtworkByTrackId[trackId] = cgImage
        }

        return trackId
    }

    /// Очищает все snapshot-данные.
    func clear() {
        snapshotsByTrackId.removeAll()
        nowPlayingArtworkByTrackId.removeAll()
    }
}
