//
//  ImportedTrack.swift
//  TrackList
//
//  Модель, представляющая импортированный трек, включая путь к файлу, метаданные и сохранённые данные доступа (bookmarkBase64)
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

struct ImportedTrack: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let filePath: String
    var orderPrefix: String
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double
    let artworkBase64: String?
    let bookmarkBase64: String?
    var artworkId: UUID?
    
    var isAvailable: Bool {
        guard let url = try? resolvedURL() else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    
    func resolvedURL() throws -> URL {
        guard let bookmarkBase64 = bookmarkBase64 else {
            throw URLError(.badURL, userInfo: ["reason": "bookmarkBase64 is nil"])
        }
        
        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw URLError(.badURL, userInfo: ["reason": "bookmarkBase64 can't be decoded"])
        }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [], 
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            print("♻️ Bookmark устарел, желательно пересоздать")
        }
        
        return url
    }
}
