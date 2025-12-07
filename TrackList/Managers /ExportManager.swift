//
//  ExportManager.swift
//  TrackList
//
//  Менеджер экспорта треков во временную папку с последующим выбором директории через UIDocumentPicker
//
//  Created by Pavel Fomin on 28.04.2025.
//

import UIKit
import Foundation
import UniformTypeIdentifiers

final class ExportManager {
    static let shared = ExportManager()

    // MARK: - Экспорт через временную папку ExportTemp

    func exportViaTempAndPicker(_ tracks: [Track], presenter: UIViewController) {
        Task {
            await self.performExport(tracks, presenter: presenter)
        }
    }

    private func performExport(_ tracks: [Track], presenter: UIViewController) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTemp", isDirectory: true)
        
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        var copiedFiles: [URL] = []
        
        for (index, track) in tracks.enumerated() {
            do {
                // 1. Получаем URL через BookmarkResolver
                guard let sourceURL = await BookmarkResolver.url(forTrack: track.id) else {
                    print("❌ Не удалось получить URL из BookmarkResolver для \(track.fileName)")
                    continue
                }

                guard sourceURL.startAccessingSecurityScopedResource() else {
                    print("❌ Нет доступа к файлу \(track.fileName)")
                    continue
                }
                defer { sourceURL.stopAccessingSecurityScopedResource() }
                
                // 3. Именование файла
                let prefix = String(format: "%02d", index + 1)
                let exportName = "\(prefix) \(track.fileName)"
                let dstURL = tempDir.appendingPathComponent(exportName)
                
                // 4. Копирование
                try FileManager.default.copyItem(at: sourceURL, to: dstURL)
                copiedFiles.append(dstURL)
                
                print("📤 Подготовлен к экспорту: \(exportName)")
                
            } catch {
                print("❌ Ошибка экспорта \(track.fileName): \(error)")
            }
        }
        
        // 5. Открываем UIDocumentPicker
        let filesToExport = copiedFiles   // ← фиксация значения ДО MainActor.run
        
        await MainActor.run {
            guard !filesToExport.isEmpty else {
                print("⚠️ Нет файлов для экспорта")
                return
            }
            
            let picker = UIDocumentPickerViewController(
                forExporting: filesToExport,
                asCopy: true
            )
            picker.shouldShowFileExtensions = true
            presenter.present(picker, animated: true)
        }
    }
}
