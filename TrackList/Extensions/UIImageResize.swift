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
        let aspectRatio = size.width / size.height
        let targetWidth = aspectRatio > 1 ? maxSize : maxSize * aspectRatio
        let targetHeight = aspectRatio > 1 ? maxSize / aspectRatio : maxSize

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight))
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: CGSize(width: targetWidth, height: targetHeight)))
        }
    }
}
