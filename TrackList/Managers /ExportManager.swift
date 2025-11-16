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
    static let shared = ExportManager()    /// Синглтон-экземпляр
    
    // MARK: - Экспорт через временную папку ExportTemp

    /// Копирует треки во временную папку и открывает системный UIDocumentPicker для выбора места сохранения
    /// - Parameters:
    ///   - tracks: Список треков для экспорта (из треклиста)
    ///   - presenter: UIViewController, на котором будет представлен UIDocumentPicker
    func exportViaTempAndPicker(_ tracks: [Track], presenter: UIViewController) {
        
        // Временная директория для экспорта
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTemp", isDirectory: true)
        
        // 1. Удаляем старую и создаём новую временную папку
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        var copiedFiles: [URL] = []
        
        // 2. Копируем по порядку каждый трек во временную папку
        for (index, track) in tracks.enumerated() {
            do {
                // Восстанавливаем URL из TrackRegistry по id трека
                guard let sourceURL = TrackRegistry.shared.resolvedURLSync(for: track.id) else {
                    print("❌ Не удалось получить URL из TrackRegistry для \(track.fileName)")
                    continue
                }
                
                // Запрашиваем доступ к ресурсу (обязательно start/stop)
                guard sourceURL.startAccessingSecurityScopedResource() else {
                    print("❌ Не удалось открыть security scope для \(track.fileName)")
                    continue
                }
                defer { sourceURL.stopAccessingSecurityScopedResource() }
                
                // Префикс с порядком (например, "01 filename.flac")
                let prefix = String(format: "%02d", index + 1)
                let exportName = "\(prefix) \(track.fileName)"
                let dstURL = tempDir.appendingPathComponent(exportName)
                
                // Копируем файл в ExportTemp
                try FileManager.default.copyItem(at: sourceURL, to: dstURL)
                copiedFiles.append(dstURL)
                print("📤 Подготовлен к экспорту: \(exportName)")
                
            } catch {
                print("❌ Не удалось экспортировать \(track.fileName): \(error)")
            }
        }
        
        // 3. Показываем системный UIDocumentPicker
        DispatchQueue.main.async {
            guard !copiedFiles.isEmpty else {
                print("⚠️ Нет файлов для экспорта")
                return
            }
            let picker = UIDocumentPickerViewController(forExporting: copiedFiles, asCopy: true)
            picker.shouldShowFileExtensions = true
            presenter.present(picker, animated: true)
        }
    }
}
