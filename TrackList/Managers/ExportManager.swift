//
//  ExportManager.swift
//  TrackList
//
//  Менеджер экспорта треков во временную папку
//  с последующим выбором директории через UIDocumentPicker.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import UIKit
import Foundation
import UniformTypeIdentifiers

final class ExportManager {
    static let shared = ExportManager()
    struct ExportResult {
        let exported: Int
        let failed: Int
    }
    // MARK: - Экспорт через временную папку ExportTemp
    func exportViaTempAndPicker(
        _ tracks: [Track],
        presenter: UIViewController
    ) async throws -> ExportResult {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTemp", isDirectory: true)
        do {
            try FileManager.default.removeItemIfExists(at: tempDir)
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        } catch {
            throw AppError.exportFailed
        }
        var copiedFiles: [URL] = []
        var failedCount = 0
        for (index, track) in tracks.enumerated() {
            do {
                guard let sourceURL = await BookmarkResolver.url(forTrack: track.trackId) else {
                    failedCount += 1
                    continue
                }
                let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() }
                }
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    failedCount += 1
                    continue
                }
                let prefix = String(format: "%02d", index + 1)
                let exportName = "\(prefix) \(track.fileName)"
                let dstURL = tempDir.appendingPathComponent(exportName)
                try FileManager.default.removeItemIfExists(at: dstURL)
                try FileManager.default.copyItem(at: sourceURL, to: dstURL)
                copiedFiles.append(dstURL)
            } catch {
                failedCount += 1
            }
        }
        guard !copiedFiles.isEmpty else {
            throw AppError.exportNoFilesPrepared
        }
        let filesToExport = copiedFiles
        await MainActor.run {
            let picker = UIDocumentPickerViewController(
                forExporting: filesToExport,
                asCopy: true
            )
            picker.shouldShowFileExtensions = true
            presenter.present(picker, animated: true)
        }
        return ExportResult(
            exported: filesToExport.count,
            failed: failedCount
        )
    }

}

private extension FileManager {
    /// Удаляет файл или папку, если они существуют.
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
