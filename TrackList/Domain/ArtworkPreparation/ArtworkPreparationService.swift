//
//  ArtworkPreparationService.swift
//  TrackList
//
//  Общий сервис подготовки обложек.
//
//  Created by Pavel Fomin on 12.06.2026.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Общий сервис подготовки обложек.
enum ArtworkPreparationService {
    /// Выполняет downsample изображения и кодирует результат в JPEG.
    static func prepare(
        _ request: ArtworkPreparationRequest
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try prepareInBackground(request)
        }.value
    }

    /// Подготавливает изображение через ImageIO вне главного потока.
    private static func prepareInBackground(
        _ request: ArtworkPreparationRequest
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(request.imageData as CFData, nil) else {
            throw ArtworkPreparationError.invalidImageData
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: request.maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw ArtworkPreparationError.invalidImageData
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ArtworkPreparationError.failedToEncodeJPEG
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: request.compressionQuality
        ]
        CGImageDestinationAddImage(
            destination,
            image,
            destinationOptions as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ArtworkPreparationError.failedToEncodeJPEG
        }
        return outputData as Data
    }
}

/// Ошибка общего сервиса подготовки обложек.
enum ArtworkPreparationError: Error {
    /// Данные не удалось открыть как изображение.
    case invalidImageData
    /// Не удалось перекодировать изображение в JPEG.
    case failedToEncodeJPEG
}
