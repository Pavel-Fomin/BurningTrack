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
    
    // MARK: - Input (immutable)
    
    let folder: LibraryFolder
    
    // MARK: - Output
    
    @Published private(set) var subfolders: [LibraryFolder]
    @Published private(set) var displayMode: DisplayMode
    
    enum DisplayMode {
        case subfolders
        case tracks
        case empty
    }
    
    // MARK: - Init
    
    init(folder: LibraryFolder) {
        self.folder = folder
        self.subfolders = folder.subfolders
        self.displayMode = folder.subfolders.isEmpty ? .tracks : .subfolders
    }
    
    // MARK: - Helpers
    
    
}
