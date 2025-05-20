//
//  ExportManager.swift
//  TrackList

//  Менеджер для экспорта треков на диск или в выбранную директорию
//
//  Created by Pavel Fomin on 28.04.2025.
//

import UIKit
import Foundation
import UniformTypeIdentifiers

final class ExportManager {
    static let shared = ExportManager()
    
    /// Копируем все треки через bookmark → tmp → UIDocumentPicker
    func exportViaTempAndPicker(_ tracks: [ImportedTrack], presenter: UIViewController) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTemp", isDirectory: true)
        
        // 1) Подготовка папки
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        var copiedFiles: [URL] = []
        
        // 2) Перебираем все ImportedTrack — без track.isAvailable
        for (index, track) in tracks.enumerated() {
            do {
                // Резолвим URL из bookmark
                var isStale = false
                let data = Data(base64Encoded: track.bookmarkBase64 ?? "")!
                let sourceURL = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                guard sourceURL.startAccessingSecurityScopedResource() else {
                    print("🚫 Не удалось открыть security scope для \(track.fileName)")
                    continue
                }
                defer { sourceURL.stopAccessingSecurityScopedResource() }

                
                // Копируем
                let prefix = String(format: "%02d", index + 1)
                let exportName = "\(prefix) \(track.fileName)"
                let dstURL = tempDir.appendingPathComponent(exportName)
                
                try FileManager.default.copyItem(at: sourceURL, to: dstURL)
                copiedFiles.append(dstURL)
                print("✅ Подготовлен для экспорта: \(exportName)")
                
            } catch {
                print("❌ Не удалось экспортировать \(track.fileName): \(error)")
            }
        }
        
        // 3) Показываем UIDocumentPicker для tmp
        DispatchQueue.main.async {
            guard !copiedFiles.isEmpty else {
                print("⚠️ Нет ни одного файла для экспорта")
                return
            }
            let picker = UIDocumentPickerViewController(forExporting: copiedFiles, asCopy: true)
            picker.shouldShowFileExtensions = true
            presenter.present(picker, animated: true)
        }
    }
}
