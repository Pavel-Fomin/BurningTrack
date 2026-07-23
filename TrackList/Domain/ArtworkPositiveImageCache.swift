//
//  ArtworkPositiveImageCache.swift
//  TrackList
//
//  Ограниченный положительный кэш подготовленных обложек.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation
import UIKit

/// Ключ готового изображения объединяет источник и один из двух канонических классов размера.
struct ArtworkCacheKey: Hashable, Sendable {
    let sourceIdentifier: ArtworkSourceIdentifier
    let sizeClass: ArtworkSizeClass
}

/// Контракт хранилища готовых обложек позволяет проверить стоимость записи без реального вытеснения NSCache.
protocol ArtworkPositiveImageCaching: AnyObject, Sendable {
    /// Возвращает готовое изображение по составному ключу.
    func image(for key: ArtworkCacheKey) -> UIImage?
    /// Сохраняет изображение с уже рассчитанной стоимостью распакованных пикселей.
    func store(_ image: UIImage, for key: ArtworkCacheKey, cost: Int)
    /// Удаляет один результат конкретного класса размера.
    func removeImage(for key: ArtworkCacheKey)
    /// Полностью очищает хранилище.
    func removeAllImages()
}

/// Производственное хранилище готовых изображений с ограничением распакованной памяти.
final class ArtworkPositiveImageCache: ArtworkPositiveImageCaching, @unchecked Sendable {
    /// Лимит одновременно удерживаемых распакованных обложек: 64 МиБ.
    static let totalCostLimit = 64 * 1024 * 1024

    /// NSCache может дополнительно очищать изображения при системном давлении на память.
    private let cache = NSCache<WrappedArtworkCacheKey, UIImage>()

    init() {
        cache.totalCostLimit = Self.totalCostLimit
    }

    /// Возвращает изображение по каноническому ключу.
    func image(for key: ArtworkCacheKey) -> UIImage? {
        cache.object(forKey: WrappedArtworkCacheKey(key))
    }

    /// Передаёт в NSCache стоимость распакованного CGImage.
    func store(_ image: UIImage, for key: ArtworkCacheKey, cost: Int) {
        cache.setObject(
            image,
            forKey: WrappedArtworkCacheKey(key),
            cost: max(1, cost)
        )
    }

    /// Удаляет одну подготовленную версию обложки.
    func removeImage(for key: ArtworkCacheKey) {
        cache.removeObject(forKey: WrappedArtworkCacheKey(key))
    }

    /// Полностью очищает кэш готовых изображений.
    func removeAllImages() {
        cache.removeAllObjects()
    }
}

/// Рассчитывает стоимость UIImage по распакованным пикселям, а не по сжатым raw-данным.
enum ArtworkImageMemoryCost {
    /// Возвращает стоимость CGImage с защитой от переполнения и безопасным fallback для не-CG UIImage.
    static func value(for image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return safeProduct(
                cgImage.bytesPerRow,
                cgImage.height
            )
        }

        // Производственная очередь создаёт UIImage только через init(cgImage:).
        // Fallback покрывает CIImage и тестовые UIImage без оценки сжатого Data.
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        guard pixelWidth.isFinite,
              pixelHeight.isFinite,
              pixelWidth > 0,
              pixelHeight > 0,
              pixelWidth <= CGFloat(Int.max),
              pixelHeight <= CGFloat(Int.max) else {
            return 1
        }

        return safeProduct(
            Int(pixelWidth.rounded(.up)),
            Int(pixelHeight.rounded(.up)),
            4
        )
    }

    /// Умножает размеры без переполнения и сохраняет ненулевую стоимость для NSCache.
    private static func safeProduct(_ values: Int...) -> Int {
        values.reduce(1) { partialResult, value in
            guard value > 0 else { return partialResult }
            guard partialResult <= Int.max / value else { return Int.max }
            return partialResult * value
        }
    }
}

/// NSObject-обёртка позволяет использовать составной Swift-ключ в NSCache.
private final class WrappedArtworkCacheKey: NSObject {
    let key: ArtworkCacheKey

    init(_ key: ArtworkCacheKey) {
        self.key = key
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? WrappedArtworkCacheKey else { return false }
        return key == other.key
    }

    override var hash: Int {
        key.hashValue
    }
}
