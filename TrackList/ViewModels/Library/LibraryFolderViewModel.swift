//
//  LibraryFolderViewModel.swift
//  TrackList
//
//  ViewModel для папки фонотеки
//
//  Created by Pavel Fomin on 08.08.2025.
//

import Foundation
import SwiftUI

@MainActor
final class LibraryFolderViewModel: ObservableObject {

    let folder: LibraryFolder

    enum DisplayMode {
        case subfolders
        case tracks
        case empty
    }

    init(folder: LibraryFolder) {
        self.folder = folder
    }

    // MARK: - Computed (без хранения)

    var subfolders: [LibraryFolder] {
        folder.subfolders
    }

    var displayMode: DisplayMode {
        if !folder.subfolders.isEmpty { return .subfolders }
        if !folder.audioFiles.isEmpty { return .tracks }
        return .empty
    }
}
