//
//  UIImage+WebP.swift
//  TrackList
//
//  Расширение для сохранения обложек в .webp
//
//  Created by Pavel Fomin on 18.05.2025.
//

import UIKit
import ImageIO
import MobileCoreServices

extension UIImage {
    /// Сохраняет изображение в WebP формате с указанным качеством
    func webpData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.webp" as CFString, 1, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }
}
