//
//  LibraryFolder.swift
//  TrackList
//
//  Created by Pavel Fomin on 27.06.2025.
//

import Foundation

// Представляет одну папку в библиотеке, включая подпапки и аудиофайлы
struct LibraryFolder: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    var subfolders: [LibraryFolder]
    var audioFiles: [URL]
    
    init(name: String, url: URL, subfolders: [LibraryFolder] = [], audioFiles: [URL] = []) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.subfolders = subfolders
        self.audioFiles = audioFiles
    }
    
}
extension LibraryFolder {
    /// Возвращает плоский массив всех аудиофайлов во всех вложенных папках
    func flattenedTracks() -> [URL] {
        var result = audioFiles
        for subfolder in subfolders {
            result.append(contentsOf: subfolder.flattenedTracks())
        }
        return result
    }
}
