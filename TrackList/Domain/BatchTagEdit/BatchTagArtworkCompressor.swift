//
//  BatchTagArtworkCompressor.swift
//  TrackList
//
//  Сжатие обложек для массового редактирования тегов.
//
//  Created by Pavel Fomin on 11.06.2026.
//

import Foundation

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
        let request = ArtworkPreparationRequest(
            imageData: data,
            maxPixelSize: option.maxPixelSize,
            compressionQuality: 0.85
        )
        do {
            return try await ArtworkPreparationService.prepare(request)
        } catch let error as ArtworkPreparationError {
            switch error {
            case .invalidImageData:
                throw BatchTagArtworkCompressionError.invalidImageData
            case .failedToEncodeJPEG:
                throw BatchTagArtworkCompressionError.failedToEncodeJPEG
            }
        } catch {
            throw error
        }
    }
}

/// Ошибка сжатия обложки.
enum BatchTagArtworkCompressionError: Error {
    /// Данные не удалось открыть как изображение.
    case invalidImageData
    /// Не удалось перекодировать изображение в JPEG.
    case failedToEncodeJPEG
}
