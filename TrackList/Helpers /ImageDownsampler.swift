//
//  ImageDownsampler.swift
//  TrackList
//
//  Утилита для быстрого даунсемплинга обложек
//
//  Created by Pavel Fomin on 11.08.2025.
//

import Foundation
import ImageIO
import CoreGraphics

@inline(__always)
func makeThumbnail(from data: Data, maxPixel: Int) -> CGImage? {
    return data.withUnsafeBytes { rawBuf in
        guard let base = rawBuf.baseAddress, rawBuf.count > 0 else { return nil }
        let cfData = CFDataCreate(kCFAllocatorDefault, base.assumingMemoryBound(to: UInt8.self), rawBuf.count)!
        guard let src = CGImageSourceCreateWithData(cfData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }
}
