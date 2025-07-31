//
//  ArtworkProvider.swift
//  TrackList
//
//  Используется во вьюшках, где нужны обложки
//
//  Created by Pavel Fomin on 31.07.2025.
//

import Foundation
import UIKit
import Combine

@MainActor
final class ArtworkProvider: ObservableObject {
    
    static let shared = ArtworkProvider()
    
    @Published var cache: [URL: UIImage] = [:]
    
    /// Сопоставление URL → UIImage
    @Published private(set) var artworkByURL: [URL: UIImage] = [:]
    
    /// Проверка: есть ли уже обложка
    func artwork(for url: URL) -> UIImage? {
        return artworkByURL[url]
    }
    
    /// Запрос на загрузку обложки (если её ещё нет)
    func loadArtworkIfNeeded(for url: URL) {
        guard artworkByURL[url] == nil else { return }
        
        ArtworkCacheManager.shared.image(for: url) { [weak self] image in
            guard let self = self, let image else { return }
            Task { @MainActor in
                self.artworkByURL[url] = image
            }
        }
    }
}
