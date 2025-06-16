//
//  UIImage+WebP.swift
//  TrackList
//
//  Расширение для сохранения обложек треков в формате .webp
//  Используется для экономии места в Documents/artworks (по сравнению с PNG/JPEG)
//
//  Требует iOS 14+ (поддержка WebP через ImageIO)
//  На старых iOS работать не будет
//
//  Created by Pavel Fomin on 18.05.2025.
//

import UIKit
import ImageIO
import MobileCoreServices

extension UIImage {
    /// Преобразует изображение в WebP-формат с заданным качеством
        ///
        /// - Parameter compressionQuality: Уровень сжатия (от 0 до 1)
        /// - Returns: Данные в формате WebP или nil при ошибке
    func webpData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.webp" as CFString, 1, nil) else {
            return nil
        }
        
        /// Опции сжатия
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        /// Добавляем изображение в destination
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        /// Завершаем и возвращаем данные
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }
}
