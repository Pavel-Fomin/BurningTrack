//
//  LibraryFolderViewModelCache.swift
//  TrackList
//
//  Created by Pavel Fomin on 25.11.2025.
//

import Foundation

@MainActor
final class LibraryFolderViewModelCache {
    static let shared = LibraryFolderViewModelCache()

    private var cache: [URL: LibraryFolderViewModel] = [:]

    func resolve(for folder: LibraryFolder) -> LibraryFolderViewModel {
        if let existing = cache[folder.url] {
            return existing
        }
        let vm = LibraryFolderViewModel(folder: folder)
        cache[folder.url] = vm
        return vm
    }
}
