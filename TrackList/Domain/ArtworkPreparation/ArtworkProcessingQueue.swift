//
//  ArtworkProcessingQueue.swift
//  TrackList
//
//  Ограниченная очередь тяжёлых операций подготовки обложек.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation
import UIKit

/// Выполняет ImageIO и кодирование вне главного потока с фиксированным параллелизмом.
final class ArtworkProcessingQueue: @unchecked Sendable {
    static let shared = ArtworkProcessingQueue()

    /// Системная очередь ограничивает число одновременно декодируемых изображений.
    private let operationQueue: OperationQueue

    /// Создаёт очередь с явным ограничением параллелизма.
    init(maxConcurrentOperationCount: Int = 3) {
        let operationQueue = OperationQueue()
        operationQueue.name = "TrackList.ArtworkProcessing"
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = max(1, maxConcurrentOperationCount)
        self.operationQueue = operationQueue
    }

    /// Подготавливает UIImage канонического класса размера только на рабочей очереди.
    func prepareImage(
        from data: Data,
        sizeClass: ArtworkSizeClass
    ) async -> UIImage? {
        await prepareImage(
            from: data,
            pixelSize: sizeClass.pixelSize
        )
    }

    /// Проверяет размер на границе ImageIO до создания источника или UIImage.
    /// Рабочие вызовы получают размер только из ArtworkSizeClass; метод остаётся доступен тестам границ.
    func prepareImage(
        from data: Data,
        pixelSize: CGSize
    ) async -> UIImage? {
        guard let maxPixel = maxPixel(for: pixelSize) else { return nil }

        return await perform { () -> UIImage? in
            autoreleasepool {
                guard let cgImage = makeThumbnail(
                    from: data,
                    maxPixel: maxPixel
                ) else {
                    return nil
                }

                // ImageIO способен вернуть объект с нулевой стороной для повреждённых данных.
                guard cgImage.width > 0, cgImage.height > 0 else {
                    return nil
                }

                return UIImage(
                    cgImage: cgImage,
                    scale: 1,
                    orientation: .up
                )
            }
        }
    }

    /// Преобразует валидный размер в предел ImageIO без переполнения Int.
    private func maxPixel(for pixelSize: CGSize) -> Int? {
        guard pixelSize.width.isFinite,
              pixelSize.height.isFinite,
              pixelSize.width > 0,
              pixelSize.height > 0 else {
            return nil
        }

        let maximumDimension = max(pixelSize.width, pixelSize.height)
        guard maximumDimension <= CGFloat(Int.max) else { return nil }

        let maxPixel = Int(maximumDimension.rounded(.up))
        return maxPixel > 0 ? maxPixel : nil
    }

    /// Выполняет переданную тяжёлую операцию на общей ограниченной очереди.
    func perform<Output>(
        _ operation: @escaping @Sendable () -> Output
    ) async -> Output {
        await withCheckedContinuation { continuation in
            operationQueue.addOperation {
                continuation.resume(returning: operation())
            }
        }
    }

    /// Выполняет бросающую ошибку тяжёлую операцию на общей ограниченной очереди.
    func perform<Output>(
        _ operation: @escaping @Sendable () throws -> Output
    ) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            operationQueue.addOperation {
                continuation.resume(with: Result {
                    try operation()
                })
            }
        }
    }
}
