//
//  UIImage+AverageColor.swift
//  TrackList
//
//  Вычисляет средний (доминирующий) цвет изображения для оформления UI
//
//  Created by Pavel Fomin on 16.10.2025.
//

import SwiftUI
import CoreImage

extension UIImage {
    /// Возвращает доминирующий (насыщенный) цвет изображения
    var averageColor: Color? {
        guard let cgImage = self.cgImage else { return nil }

        // Уменьшаем изображение до 1x1 пикселя
        let width = 1, height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(
            data: &pixel,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0

        // Конвертация в HSB для коррекции насыщенности и яркости
        var h: CGFloat = 0, s: CGFloat = 0, bVal: CGFloat = 0, a: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1)
            .getHue(&h, saturation: &s, brightness: &bVal, alpha: &a)

        // Немного усиливаем насыщенность и балансируем яркость
        let boosted = UIColor(
            hue: h,
            saturation: min(s * 1.6, 1.0),
            brightness: min(bVal * 1.2, 1.0),
            alpha: 1
        )

        return Color(boosted)
    }
}
