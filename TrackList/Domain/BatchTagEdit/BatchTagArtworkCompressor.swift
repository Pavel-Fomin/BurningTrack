//
//  BatchTagArtworkCompressor.swift
//  TrackList
//
//  Сжатие обложек для массового редактирования тегов.
//
//  Created by Pavel Fomin on 11.06.2026.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Сжимает данные обложки для массового редактирования тегов.
enum BatchTagArtworkCompressor {
    /// Сжимает обложку по максимальному размеру стороны.
    ///
    /// - Parameters:
    ///   - data: Исходные данные изображения.
    ///   - option: Вариант сжатия.
    /// - Returns: JPEG-данные сжатой обложки.
    static func compress(
        data: Data,
        option: BatchArtworkCompressionOption
    ) async throws -> Data {
        let maxPixelSize = option.maxPixelSize
        return try await Task.detached(priority: .userInitiated) {
            try compressInBackground(
                data: data,
                maxPixelSize: maxPixelSize
            )
        }.value
    }

    /// Сжимает изображение через ImageIO вне главного потока.
    private static func compressInBackground(
        data: Data,
        maxPixelSize: Int
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw BatchTagArtworkCompressionError.invalidImageData
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw BatchTagArtworkCompressionError.invalidImageData
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw BatchTagArtworkCompressionError.failedToEncodeJPEG
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]
        CGImageDestinationAddImage(
            destination,
            image,
            destinationOptions as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw BatchTagArtworkCompressionError.failedToEncodeJPEG
        }
        return outputData as Data
    }
}

/// Ошибка сжатия обложки.
enum BatchTagArtworkCompressionError: Error {
    /// Данные не удалось открыть как изображение.
    case invalidImageData
    /// Не удалось перекодировать изображение в JPEG.
    case failedToEncodeJPEG
}
