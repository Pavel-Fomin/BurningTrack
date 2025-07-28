//
//  ImageUtils.swift
//  TrackList
//
//  Создаёт новое изображение с отрисовкой в графическом контексте
//
//  Created by Pavel Fomin on 29.07.2025.
//

import UIKit

func normalize(_ image: UIImage) -> UIImage {
    
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    image.draw(in: CGRect(origin: .zero, size: image.size))
    let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return normalizedImage
}
