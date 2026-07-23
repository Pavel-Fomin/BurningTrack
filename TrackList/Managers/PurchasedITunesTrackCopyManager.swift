//
//  PurchasedITunesTrackCopyManager.swift
//  TrackList
//
//  Копирование купленного iTunes-трека в выбранную папку фонотеки.
//
//  Created by Codex on 03.07.2026.
//

import Foundation

/// Ошибки копирования iTunes-трека на уровне файлового слоя.
enum PurchasedITunesTrackCopyError: Error {
    case sourceUnavailable
    case destinationFolderUnavailable
    case exportSessionUnavailable
    case exportFailed(underlying: Error?)
    case copyFailed(underlying: Error)

}

/// Результат копирования iTunes-трека в фонотеку.
struct PurchasedITunesTrackCopyResult {
    /// URL созданного файла в выбранной папке.
    let fileURL: URL
    /// Идентификатор выбранной папки назначения.
    let folderId: UUID
    /// Отображаемое имя выбранной папки назначения.
    let folderName: String?
    /// Идентификатор корневой папки фонотеки для последующего sync.
    let rootFolderId: UUID
    /// URL корневой папки фонотеки для последующего sync.
    let rootFolderURL: URL
}

/// Выполняет физическое копирование runtime iTunes-ассета в папку фонотеки.
///
/// Менеджер не показывает UI, не пишет в TrackRegistry вручную и не использует
/// BookmarkResolver для исходного iTunes-трека.
actor PurchasedITunesTrackCopyManager {

    // MARK: - Singleton

    static let shared = PurchasedITunesTrackCopyManager()

    /// Общий writer не содержит логики фонотеки и используется также внешним экспортом.
    private let assetWriter = PurchasedITunesAssetWriter()

    private init() {}

    // MARK: - Public API

    /// Копирует iTunes-трек в выбранную папку фонотеки.
    func copy(
        _ track: PurchasedITunesPlayableTrack,
        toFolder destinationFolderId: UUID
    ) async throws -> PurchasedITunesTrackCopyResult {
        guard track.isAvailable else {
            throw PurchasedITunesTrackCopyError.sourceUnavailable
        }

        let destinationContext = try await destinationContext(
            for: destinationFolderId
        )

        let accessStarted = try await startDestinationAccess(
            rootFolderId: destinationContext.rootFolder.id,
            rootFolderURL: destinationContext.rootFolder.url
        )
        defer {
            if accessStarted {
                destinationContext.rootFolder.url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = PurchasedITunesAsset(track: track)
        let copyPlan = try makeCopyPlan(
            asset: asset,
            destinationFolderURL: destinationContext.folder.url
        )

        let temporaryURL = try makeTemporaryURL(
            fileExtension: copyPlan.writePlan.fileExtension
        )

        do {
            try await assetWriter.write(
                asset,
                to: temporaryURL,
                using: copyPlan.writePlan
            )

            try FileManager.default.moveItem(
                at: temporaryURL,
                to: copyPlan.destinationURL
            )

            return PurchasedITunesTrackCopyResult(
                fileURL: copyPlan.destinationURL,
                folderId: destinationFolderId,
                folderName: displayFolderName(
                    destinationContext.folder.name
                ),
                rootFolderId: destinationContext.rootFolder.id,
                rootFolderURL: destinationContext.rootFolder.url
            )
        } catch let error as PurchasedITunesAssetWriterError {
            try? removeTemporaryFile(at: temporaryURL)
            throw copyError(from: error)
        } catch let error as PurchasedITunesTrackCopyError {
            try? removeTemporaryFile(at: temporaryURL)
            throw error
        } catch {
            try? removeTemporaryFile(at: temporaryURL)
            throw PurchasedITunesTrackCopyError.copyFailed(underlying: error)
        }
    }

    // MARK: - Destination

    /// Контекст выбранной папки и её прикреплённого корня.
    private struct DestinationContext {
        let folder: LibraryFolder
        let rootFolder: LibraryFolder
    }

    /// Возвращает отображаемое имя папки, если оно есть.
    private func displayFolderName(
        _ name: String
    ) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// План записи файла с уже подобранным уникальным именем.
    private struct CopyPlan {
        let destinationURL: URL
        let writePlan: PurchasedITunesAssetWriter.WritePlan
    }

    /// Получает выбранную папку и её root-папку из текущего дерева фонотеки.
    private func destinationContext(
        for folderId: UUID
    ) async throws -> DestinationContext {
        let context = await MainActor.run {
            guard let folder = MusicLibraryManager.shared.folder(for: folderId),
                  let rootFolder = MusicLibraryManager.shared.rootFolder(for: folderId)
            else {
                return nil as DestinationContext?
            }

            return DestinationContext(
                folder: folder,
                rootFolder: rootFolder
            )
        }

        guard let context else {
            throw PurchasedITunesTrackCopyError.destinationFolderUnavailable
        }

        return context
    }

    /// Открывает доступ к root-папке назначения через существующий security-scoped механизм.
    private func startDestinationAccess(
        rootFolderId: UUID,
        rootFolderURL: URL
    ) async throws -> Bool {
        let hasRuntimeAccess = await MainActor.run {
            MusicLibraryManager.shared.hasActiveRootAccess(
                rootFolderId: rootFolderId,
                url: rootFolderURL
            )
        }

        let started = rootFolderURL.startAccessingSecurityScopedResource()
        guard started || hasRuntimeAccess else {
            throw PurchasedITunesTrackCopyError.destinationFolderUnavailable
        }

        return started
    }

    // MARK: - Copy plan

    /// Создаёт план копирования с безопасным уникальным именем файла.
    private func makeCopyPlan(
        asset: PurchasedITunesAsset,
        destinationFolderURL: URL
    ) throws -> CopyPlan {
        let writePlan = try assetWriter.makeWritePlan(for: asset)
        let baseName = PurchasedITunesAssetWriter.displayFileBaseName(
            for: asset
        )
        let destinationURL = uniqueDestinationURL(
            baseName: baseName,
            fileExtension: writePlan.fileExtension,
            in: destinationFolderURL
        )

        return CopyPlan(
            destinationURL: destinationURL,
            writePlan: writePlan
        )
    }

    /// Подбирает свободное имя файла, добавляя суффикс 2, 3 и далее.
    private func uniqueDestinationURL(
        baseName: String,
        fileExtension: String,
        in folderURL: URL
    ) -> URL {
        let initialURL = folderURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)

        guard FileManager.default.fileExists(atPath: initialURL.path) else {
            return initialURL
        }

        var index = 2
        while true {
            let candidate = folderURL
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)

            if FileManager.default.fileExists(atPath: candidate.path) == false {
                return candidate
            }

            index += 1
        }
    }

    /// Сохраняет прежнее отображение ошибок одиночного копирования.
    private func copyError(
        from error: PurchasedITunesAssetWriterError
    ) -> PurchasedITunesTrackCopyError {
        switch error {
        case .sourceUnavailable:
            return .sourceUnavailable
        case .exportSessionUnavailable:
            return .exportSessionUnavailable
        case .exportFailed(let underlying):
            return .exportFailed(underlying: underlying)
        case .sourceSizeUnavailable:
            return .copyFailed(underlying: error)
        case .copyFailed(let underlying):
            return .copyFailed(underlying: underlying)
        }
    }

    /// Создаёт уникальный временный URL для промежуточной записи.
    private func makeTemporaryURL(
        fileExtension: String
    ) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PurchasedITunesCopy",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        return temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }

    /// Удаляет временный файл после ошибки.
    private func removeTemporaryFile(
        at url: URL
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
