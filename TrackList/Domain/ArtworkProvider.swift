//
//  ArtworkProvider.swift
//  TrackList
//
//  Провайдер обложек треков.
//
//  Ответственность:
//  — получить UIImage из artworkData
//  — выполнить даунсемплинг под заданное назначение
//  — закэшировать результат по (trackId + purpose)
//
//  НЕ делает:
//  — IO
//  — async
//  — работу с URL
//  — загрузку метаданных
//
//  Использует:
//  — ArtworkPurpose (доменный контракт)
//  — ArtworkPurposeSizes (инварианты размеров)
//  — makeThumbnail (ImageIO)
//
//  Created by PavelFomin on 09.01.2026.
//


import UIKit
import Foundation

// MARK: - Ключ кэша

private struct ArtworkCacheKey: Hashable {
    let trackId: UUID
    let purpose: ArtworkPurpose
}

// MARK: - Провайдер

final class ArtworkProvider {

    static let shared = ArtworkProvider()
    private let cache = NSCache<WrappedKey, UIImage>()  /// NSCache управляется системой (memory pressure)
    
    private init() {}

    // MARK: - Публичный API

    /// Возвращает обложку трека нужного качества.
    ///
    /// - Parameters:
    ///   - trackId: стабильный идентификатор трека
    ///   - artworkData: сырые данные обложки из метаданных
    ///   - purpose: назначение обложки
    ///
    /// - Returns: UIImage нужного размера или nil
    func image(
        trackId: UUID,
        artworkData: Data?,
        purpose: ArtworkPurpose
    ) -> UIImage? {

        let key = ArtworkCacheKey(trackId: trackId, purpose: purpose)
        let wrappedKey = WrappedKey(key)

        // 1. Проверяем кэш
        if let cached = cache.object(forKey: wrappedKey) {
            return cached
        }

        // 2. Нет данных — нечего обрабатывать
        guard let data = artworkData else {
            return nil
        }

        // 3. Получаем целевой размер (инвариант)
        let maxPixel = ArtworkPurposeSizes.maxPixel(for: purpose)

        // 4. Даунсемплинг через ImageIO
        guard let cgImage = makeThumbnail(from: data, maxPixel: maxPixel) else {
            return nil
        }

        let scale = UITraitCollection.current.displayScale

        let image = UIImage(
            cgImage: cgImage,
            scale: scale,
            orientation: .up
        )

        // 5. Кэшируем готовое изображение
        cache.setObject(image, forKey: wrappedKey)

        return image
    }
}

// MARK: - Обёртка ключа для NSCache

private final class WrappedKey: NSObject {

    let key: ArtworkCacheKey

    init(_ key: ArtworkCacheKey) {
        self.key = key
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? WrappedKey else { return false }
        return key == other.key
    }

    override var hash: Int {
        key.hashValue
    }
}
