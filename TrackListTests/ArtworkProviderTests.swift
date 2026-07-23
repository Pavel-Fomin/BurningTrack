//
//  ArtworkProviderTests.swift
//  TrackList
//
//  Проверка классов размера, кэширования и отрицательных результатов подсистемы обложек.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import CoreGraphics
import UIKit
import XCTest
@testable import TrackList

final class ArtworkProviderTests: XCTestCase {
    /// Одновременные компактные purpose используют единственную small-подготовку.
    func testSmallPurposesShareSinglePreparation() async {
        let expectedImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: expectedImage, largeResult: UIImage())
        let provider = makeProvider(spy: spy)
        let trackId = UUID()

        async let trackListImage = provider.image(
            for: makeRequest(trackId: trackId, purpose: .trackList)
        )
        async let miniPlayerImage = provider.image(
            for: makeRequest(trackId: trackId, purpose: .miniPlayer)
        )
        let images = await (trackListImage, miniPlayerImage)
        let smallPreparationCount = await spy.count(for: .small)
        let largePreparationCount = await spy.count(for: .large)

        XCTAssertTrue(images.0 === expectedImage)
        XCTAssertTrue(images.1 === expectedImage)
        XCTAssertEqual(smallPreparationCount, 1)
        XCTAssertEqual(largePreparationCount, 0)
    }

    /// Одновременные крупные purpose используют единственную large-подготовку.
    func testLargePurposesShareSinglePreparation() async {
        let expectedImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: UIImage(), largeResult: expectedImage)
        let provider = makeProvider(spy: spy)
        let trackId = UUID()

        async let trackInfoImage = provider.image(
            for: makeRequest(trackId: trackId, purpose: .trackInfoSheet)
        )
        async let nowPlayingImage = provider.image(
            for: makeRequest(trackId: trackId, purpose: .nowPlaying)
        )
        let images = await (trackInfoImage, nowPlayingImage)
        let smallPreparationCount = await spy.count(for: .small)
        let largePreparationCount = await spy.count(for: .large)

        XCTAssertTrue(images.0 === expectedImage)
        XCTAssertTrue(images.1 === expectedImage)
        XCTAssertEqual(smallPreparationCount, 0)
        XCTAssertEqual(largePreparationCount, 1)
    }

    /// Один источник может иметь ровно по одному результату каждого класса размера.
    func testSmallAndLargeCreateDifferentPreparedImages() async {
        let smallImage = UIImage()
        let largeImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: smallImage, largeResult: largeImage)
        let provider = makeProvider(spy: spy)
        let trackId = UUID()

        async let smallResult = provider.image(
            for: makeRequest(trackId: trackId, purpose: .trackList)
        )
        async let largeResult = provider.image(
            for: makeRequest(trackId: trackId, purpose: .nowPlaying)
        )
        let images = await (smallResult, largeResult)
        let smallPreparationCount = await spy.count(for: .small)
        let largePreparationCount = await spy.count(for: .large)

        XCTAssertTrue(images.0 === smallImage)
        XCTAssertTrue(images.1 === largeImage)
        XCTAssertFalse(images.0 === images.1)
        XCTAssertEqual(smallPreparationCount, 1)
        XCTAssertEqual(largePreparationCount, 1)
    }

    /// Повторный small-запрос возвращается из положительного кэша без новой подготовки.
    func testRepeatedSmallRequestUsesPositiveCache() async {
        let expectedImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: expectedImage, largeResult: UIImage())
        let provider = makeProvider(spy: spy)
        let request = makeRequest(purpose: .trackList)

        let firstImage = await provider.image(for: request)
        let secondImage = await provider.image(for: request)
        let smallPreparationCount = await spy.count(for: .small)

        XCTAssertTrue(firstImage === expectedImage)
        XCTAssertTrue(secondImage === expectedImage)
        XCTAssertEqual(smallPreparationCount, 1)
    }

    /// Повторный large-запрос возвращается из положительного кэша без новой подготовки.
    func testRepeatedLargeRequestUsesPositiveCache() async {
        let expectedImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: UIImage(), largeResult: expectedImage)
        let provider = makeProvider(spy: spy)
        let request = makeRequest(purpose: .nowPlaying)

        let firstImage = await provider.image(for: request)
        let secondImage = await provider.image(for: request)
        let largePreparationCount = await spy.count(for: .large)

        XCTAssertTrue(firstImage === expectedImage)
        XCTAssertTrue(secondImage === expectedImage)
        XCTAssertEqual(largePreparationCount, 1)
    }

    /// Фактический nil добавляет исходную обложку в отрицательный кэш.
    func testNilPreparationCreatesNegativeCache() async {
        let spy = ArtworkPreparationSpy(smallResult: nil, largeResult: nil)
        let provider = makeProvider(spy: spy)
        let request = makeRequest(purpose: .trackList)

        let image = await provider.image(for: request)
        let smallPreparationCount = await spy.count(for: .small)

        XCTAssertNil(image)
        XCTAssertEqual(smallPreparationCount, 1)
    }

    /// Отрицательный кэш источника блокирует последующие small- и large-запросы.
    func testNegativeCacheBlocksEverySizeClass() async {
        let spy = ArtworkPreparationSpy(smallResult: nil, largeResult: nil)
        let provider = makeProvider(spy: spy)
        let trackId = UUID()
        let smallRequest = makeRequest(trackId: trackId, purpose: .trackList)
        let largeRequest = makeRequest(trackId: trackId, purpose: .nowPlaying)

        let smallImage = await provider.image(for: smallRequest)
        let largeImage = await provider.image(for: largeRequest)
        let preparationCount = await spy.totalCount

        XCTAssertNil(smallImage)
        XCTAssertNil(largeImage)
        XCTAssertEqual(preparationCount, 1)
    }

    /// Изменение artworkData очищает отрицательный кэш прежнего источника.
    func testInvalidateClearsNegativeCacheForPreviousSource() async {
        let spy = ArtworkPreparationSpy(smallResult: nil, largeResult: nil)
        let provider = makeProvider(spy: spy)
        let trackId = UUID()
        let request = makeRequest(trackId: trackId, purpose: .trackList)

        let firstImage = await provider.image(for: request)
        await provider.invalidate(trackId: trackId)
        let secondImage = await provider.image(for: request)
        let smallPreparationCount = await spy.count(for: .small)

        XCTAssertNil(firstImage)
        XCTAssertNil(secondImage)
        XCTAssertEqual(smallPreparationCount, 2)
    }

    /// Изменение artworkData удаляет из положительного кэша small и large прежнего источника.
    func testInvalidateRemovesBothPositiveVariantsOfPreviousSource() async {
        let smallImage = UIImage()
        let largeImage = UIImage()
        let spy = ArtworkPreparationSpy(smallResult: smallImage, largeResult: largeImage)
        let cache = ArtworkPositiveCacheSpy()
        let provider = makeProvider(spy: spy, positiveCache: cache)
        let trackId = UUID()
        let smallRequest = makeRequest(trackId: trackId, purpose: .trackList)
        let largeRequest = makeRequest(trackId: trackId, purpose: .nowPlaying)

        _ = await provider.image(for: smallRequest)
        _ = await provider.image(for: largeRequest)
        await provider.invalidate(trackId: trackId)
        _ = await provider.image(for: smallRequest)
        _ = await provider.image(for: largeRequest)

        let expectedRemovedKeys: Set<ArtworkCacheKey> = [
            ArtworkCacheKey(
                sourceIdentifier: smallRequest.sourceIdentifier,
                sizeClass: .small
            ),
            ArtworkCacheKey(
                sourceIdentifier: smallRequest.sourceIdentifier,
                sizeClass: .large
            )
        ]
        let smallPreparationCount = await spy.count(for: .small)
        let largePreparationCount = await spy.count(for: .large)
        XCTAssertEqual(Set(cache.removedKeys), expectedRemovedKeys)
        XCTAssertEqual(smallPreparationCount, 2)
        XCTAssertEqual(largePreparationCount, 2)
    }

    /// Нулевая ширина не попадает в ImageIO или UIKit при подготовке на рабочей очереди.
    func testZeroWidthDoesNotProduceImage() async {
        let queue = ArtworkProcessingQueue(maxConcurrentOperationCount: 1)
        let image = await queue.prepareImage(
            from: Data([0x00]),
            pixelSize: CGSize(width: 0, height: 96)
        )

        XCTAssertNil(image)
    }

    /// Нулевая высота не попадает в ImageIO или UIKit при подготовке на рабочей очереди.
    func testZeroHeightDoesNotProduceImage() async {
        let queue = ArtworkProcessingQueue(maxConcurrentOperationCount: 1)
        let image = await queue.prepareImage(
            from: Data([0x00]),
            pixelSize: CGSize(width: 96, height: 0)
        )

        XCTAssertNil(image)
    }

    /// Стоимость изображения равна фактическому числу байтов строк CGImage.
    func testImageMemoryCostUsesCGImageBytesPerRowAndHeight() {
        let image = makeCGImageBackedImage(width: 3, height: 2)
        let expectedCost = image.cgImage!.bytesPerRow * image.cgImage!.height

        XCTAssertEqual(ArtworkImageMemoryCost.value(for: image), expectedCost)
    }

    /// Provider передаёт в положительный кэш ненулевую стоимость подготовленного изображения.
    func testPositiveCacheReceivesNonZeroImageCost() async {
        let image = makeCGImageBackedImage(width: 3, height: 2)
        let spy = ArtworkPreparationSpy(smallResult: image, largeResult: image)
        let cache = ArtworkPositiveCacheSpy()
        let provider = makeProvider(spy: spy, positiveCache: cache)

        _ = await provider.image(for: makeRequest(purpose: .trackList))

        XCTAssertEqual(cache.storedCosts, [ArtworkImageMemoryCost.value(for: image)])
        XCTAssertGreaterThan(cache.storedCosts[0], 0)
    }

    /// Производственный положительный кэш ограничен 64 МиБ распакованной памяти.
    func testPositiveCacheUses64MiBTotalCostLimit() {
        XCTAssertEqual(
            ArtworkPositiveImageCache.totalCostLimit,
            64 * 1024 * 1024
        )
    }

    /// Все purpose распределены ровно между двумя каноническими классами размера.
    func testArtworkPurposeSizeClassDistribution() {
        XCTAssertEqual(ArtworkPurpose.trackList.sizeClass, .small)
        XCTAssertEqual(ArtworkPurpose.miniPlayer.sizeClass, .small)
        XCTAssertEqual(ArtworkPurpose.batchTagPreview.sizeClass, .small)
        XCTAssertEqual(ArtworkPurpose.toast.sizeClass, .small)
        XCTAssertEqual(ArtworkPurpose.trackInfoSheet.sizeClass, .large)
        XCTAssertEqual(ArtworkPurpose.nowPlaying.sizeClass, .large)
    }

    /// Канонические классы передают ImageIO только установленные размеры в пикселях.
    func testArtworkSizeClassesUseCanonicalPixelSizes() {
        XCTAssertEqual(ArtworkSizeClass.small.pixelSize, CGSize(width: 96, height: 96))
        XCTAssertEqual(ArtworkSizeClass.large.pixelSize, CGSize(width: 512, height: 512))
    }

    /// Повторно созданные запросы одинаковых raw-данных имеют одинаковый идентификатор источника.
    func testEmbeddedArtworkSourceIdentifierIsStableAcrossRequests() {
        let trackId = UUID()
        let artworkData = Data([1, 2, 3])
        let firstRequest = makeRequest(
            trackId: trackId,
            purpose: .trackList,
            artworkData: artworkData
        )
        let secondRequest = makeRequest(
            trackId: trackId,
            purpose: .miniPlayer,
            artworkData: artworkData
        )

        XCTAssertEqual(firstRequest.sourceIdentifier, secondRequest.sourceIdentifier)
        XCTAssertEqual(firstRequest.sizeClass, secondRequest.sizeClass)
    }

    /// Создаёт provider с внедрённой подготовкой и при необходимости с тестовым кэшем.
    private func makeProvider(
        spy: ArtworkPreparationSpy,
        positiveCache: any ArtworkPositiveImageCaching = ArtworkPositiveImageCache()
    ) -> ArtworkProvider {
        ArtworkProvider(
            prepareImage: { data, sizeClass in
                await spy.prepare(data: data, sizeClass: sizeClass)
            },
            positiveCache: positiveCache
        )
    }

    /// Создаёт минимальный запрос без реального декодирования для внедрённой подготовки.
    private func makeRequest(
        trackId: UUID = UUID(),
        purpose: ArtworkPurpose,
        artworkData: Data = Data([1, 2, 3])
    ) -> ArtworkRequest {
        ArtworkRequest(
            trackId: trackId,
            artworkData: artworkData,
            purpose: purpose,
            sourceIdentifier: .embeddedArtwork(data: artworkData)
        )
    }

    /// Создаёт UIImage с реальным CGImage для проверки стоимости распакованных пикселей.
    private func makeCGImageBackedImage(width: Int, height: Int) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!
        return UIImage(cgImage: context.makeImage()!)
    }
}

/// Потокобезопасно считает обращения к внедрённой подготовке по классу размера.
private actor ArtworkPreparationSpy {
    private let smallResult: UIImage?
    private let largeResult: UIImage?
    private var counts: [ArtworkSizeClass: Int] = [:]

    init(smallResult: UIImage?, largeResult: UIImage?) {
        self.smallResult = smallResult
        self.largeResult = largeResult
    }

    /// Имитирует асинхронную подготовку, чтобы конкурентные запросы успели объединиться.
    func prepare(data: Data, sizeClass: ArtworkSizeClass) async -> UIImage? {
        counts[sizeClass, default: 0] += 1
        await Task.yield()

        switch sizeClass {
        case .small:
            return smallResult
        case .large:
            return largeResult
        }
    }

    /// Возвращает число подготовок конкретного класса размера.
    func count(for sizeClass: ArtworkSizeClass) -> Int {
        counts[sizeClass, default: 0]
    }

    /// Возвращает общее число подготовок всех классов размера.
    var totalCount: Int {
        counts.values.reduce(0, +)
    }
}

/// Тестовое хранилище фиксирует переданную provider стоимость без сильных ссылок вне самого теста.
private final class ArtworkPositiveCacheSpy: ArtworkPositiveImageCaching, @unchecked Sendable {
    private var images: [ArtworkCacheKey: UIImage] = [:]
    private(set) var storedCosts: [Int] = []
    private(set) var removedKeys: [ArtworkCacheKey] = []

    /// Возвращает ранее сохранённое изображение.
    func image(for key: ArtworkCacheKey) -> UIImage? {
        images[key]
    }

    /// Сохраняет изображение и стоимость, переданные ArtworkProvider.
    func store(_ image: UIImage, for key: ArtworkCacheKey, cost: Int) {
        images[key] = image
        storedCosts.append(cost)
    }

    /// Удаляет одну версию изображения и фиксирует ключ инвалидирования.
    func removeImage(for key: ArtworkCacheKey) {
        images[key] = nil
        removedKeys.append(key)
    }

    /// Полностью очищает тестовое хранилище.
    func removeAllImages() {
        images.removeAll()
    }
}
