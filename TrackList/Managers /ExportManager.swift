//
//  ExportManager.swift
//  TrackList

//  Менеджер для экспорта треков на диск или в выбранную директорию
//
//  Created by Pavel Fomin on 28.04.2025.
//

import UIKit
import Foundation

final class ExportManager {
    func exportTracks(
        _ tracks: [ImportedTrack],
        to destinationFolder: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                for (index, importedTrack) in tracks.enumerated() {
                    let sourceURL = try importedTrack.resolvedURL()
                    
                    let accessGranted = sourceURL.startAccessingSecurityScopedResource()
                    defer {
                        if accessGranted {
                            sourceURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    let originalName = sourceURL.lastPathComponent
                    let exportName = String(format: "%02d %@", index + 1, originalName)
                    let destinationURL = destinationFolder.appendingPathComponent(exportName)
                    
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
