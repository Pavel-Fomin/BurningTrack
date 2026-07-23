//
//  PurchasedITunesMusicProvider.swift
//  TrackList
//
//  Читает локальные треки из системной медиатеки iOS.
//  Раздел называется “Куплено в iTunes”, но технически фильтр основан
//  на доступности файла, отсутствии iCloud-статуса и отсутствии DRM.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Foundation
import MediaPlayer
import UIKit

enum PurchasedITunesMusicAccessState: Equatable {
    /// Пользователь ещё не отвечал на системный запрос доступа.
    case notDetermined
    /// Доступ запрещён пользователем или ограничен системой.
    case denied
    /// Доступ к системной медиатеке разрешён.
    case authorized
}

final class PurchasedITunesMusicProvider {

    // MARK: - Доступ

    /// Запрашивает доступ к системной медиатеке только при первом обращении.
    func requestAccessIfNeeded() async -> PurchasedITunesMusicAccessState {
        let currentStatus = MPMediaLibrary.authorizationStatus()

        switch currentStatus {
        case .authorized:
            return .authorized

        case .denied, .restricted:
            return .denied

        case .notDetermined:
            return await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { status in
                    // Возвращаем внутреннее состояние экрана без протекания типов MediaPlayer наружу.
                    switch status {
                    case .authorized:
                        continuation.resume(returning: .authorized)
                    case .denied, .restricted:
                        continuation.resume(returning: .denied)
                    case .notDetermined:
                        continuation.resume(returning: .notDetermined)
                    @unknown default:
                        continuation.resume(returning: .denied)
                    }
                }
            }

        @unknown default:
            return .denied
        }
    }

    // MARK: - Треки

    /// Загружает локальные музыкальные элементы, у которых есть доступный файловый assetURL.
    func loadTracks() -> [PurchasedITunesTrack] {
        let query = MPMediaQuery.songs()
        let items = query.items ?? []

        return items.compactMap { item in
            guard item.mediaType.contains(.music) else {
                return nil
            }

            guard item.isCloudItem == false else {
                return nil
            }

            guard item.hasProtectedAsset == false else {
                return nil
            }

            guard let assetURL = item.assetURL else {
                return nil
            }

            // Если в медиатеке нет названия, показываем имя локального ассета.
            let fallbackTitle = assetURL.deletingPathExtension().lastPathComponent

            return PurchasedITunesTrack(
                id: item.persistentID,
                title: item.title ?? fallbackTitle,
                artist: item.artist,
                album: item.albumTitle,
                artworkData: artworkData(for: item),
                duration: item.playbackDuration,
                assetURL: assetURL
            )
        }
        .sorted { first, second in
            first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }

    /// Готовит runtime-данные обложки из MediaPlayer без записи на диск.
    private func artworkData(
        for item: MPMediaItem
    ) -> Data? {
        autoreleasepool {
            guard let artwork = item.artwork else {
                return nil
            }

            // Берём канонический large-размер, а компактные экраны готовят собственный small-thumbnail.
            let targetSize = ArtworkSizeClass.large.pixelSize

            guard let image = artwork.image(at: targetSize) else {
                return nil
            }

            // JPEG обычно соответствует музыкальным обложкам; PNG оставляем запасным вариантом.
            return image.jpegData(compressionQuality: 0.92) ?? image.pngData()
        }
    }
}
