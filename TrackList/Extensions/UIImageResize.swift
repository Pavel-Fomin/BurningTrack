//
//  UIImageResize.swift
//  TrackList
//
//  Расширение для ресайза обложек
//
//  Created by Pavel Fomin on 01.08.2025.
//

import UIKit

extension UIImage {
    func resized(to maxSize: CGFloat) -> UIImage {
        guard let cgImage = self.cgImage else { return self }

        let width = cgImage.width
        let height = cgImage.height

        let scale = maxSize / CGFloat(max(width, height))
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return self
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        if let scaledImage = context.makeImage() {
            return UIImage(cgImage: scaledImage)
        }

        return self
    }
}
