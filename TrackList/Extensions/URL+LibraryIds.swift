//
//  URL+LibraryIds.swift
//  TrackList
//
//  Created by Pavel Fomin on 12.11.2025.
//

import Foundation

extension URL {
    
    // Стабильный ID папки, совпадающий с тем, что создаётся в LibraryFolder.init
    var libraryFolderId: UUID {
        UUID.v5(from: self.standardizedFileURL.absoluteString)
    }
}
