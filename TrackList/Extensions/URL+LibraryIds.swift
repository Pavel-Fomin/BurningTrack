//
//  URL+LibraryIds.swift
//  TrackList
//
//  Вычисляет стабильную идентичность папки из стандартизированного URL.
//
//  Created by Pavel Fomin on 12.11.2025.
//

import Foundation

extension URL {
    
    // Стандартизация URL не меняет идентичность при повторном создании значения папки.
    var libraryFolderId: UUID {
        UUID.v5(from: self.standardizedFileURL.absoluteString)
    }
}
