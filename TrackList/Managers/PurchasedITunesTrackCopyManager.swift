//
//  PurchasedITunesTrackCopyManager.swift
//  TrackList
//
//  Копирование купленного iTunes-трека в выбранную папку фонотеки.
//
//  Created by Codex on 03.07.2026.
//

import Foundation
@preconcurrency import AVFoundation

/// Ошибки копирования iTunes-трека на уровне файлового слоя.
enum PurchasedITunesTrackCopyError: LocalizedError {
    case sourceUnavailable
    case destinationFolderUnavailable
    case exportSessionUnavailable
    case exportFailed(underlying: Error?)
    case copyFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return "Исходный iTunes-трек недоступен."
        case .destinationFolderUnavailable:
            return "Папка назначения недоступна."
        case .exportSessionUnavailable:
            return "Не удалось подготовить экспорт iTunes-трека."
        case .exportFailed(let underlying):
            return "Не удалось экспортировать iTunes-трек: \(underlying?.localizedDescription ?? "неизвестная ошибка")"
        case .copyFailed(let underlying):
            return "Не удалось скопировать iTunes-трек: \(underlying.localizedDescription)"
        }
    }
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

        let copyPlan = try makeCopyPlan(
            track: track,
            destinationFolderURL: destinationContext.folder.url
        )

        let temporaryURL = try makeTemporaryURL(
            fileExtension: copyPlan.sourceWritePlan.fileExtension
        )

        do {
            try await writeSource(
                track,
                toTemporaryURL: temporaryURL,
                using: copyPlan.sourceWritePlan
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
        let sourceWritePlan: SourceWritePlan
    }

    /// Способ записи исходного iTunes-ассета во временный файл.
    private enum SourceWritePlan {
        case fileCopy(fileExtension: String)
        case assetExport(fileExtension: String, outputFileType: AVFileType)

        var fileExtension: String {
            switch self {
            case .fileCopy(let fileExtension):
                return fileExtension
            case .assetExport(let fileExtension, _):
                return fileExtension
            }
        }
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
        track: PurchasedITunesPlayableTrack,
        destinationFolderURL: URL
    ) throws -> CopyPlan {
        let sourceWritePlan = try makeSourceWritePlan(for: track.assetURL)
        let baseName = displayFileBaseName(for: track)
        let destinationURL = uniqueDestinationURL(
            baseName: baseName,
            fileExtension: sourceWritePlan.fileExtension,
            in: destinationFolderURL
        )

        return CopyPlan(
            destinationURL: destinationURL,
            sourceWritePlan: sourceWritePlan
        )
    }

    /// Определяет способ записи и расширение итогового файла.
    private func makeSourceWritePlan(
        for sourceURL: URL
    ) throws -> SourceWritePlan {
        if sourceURL.isFileURL {
            return .fileCopy(
                fileExtension: preferredFileExtension(for: sourceURL)
            )
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw PurchasedITunesTrackCopyError.exportSessionUnavailable
        }

        let preferredExtension = preferredFileExtension(for: sourceURL)
        if let preferredType = avFileType(for: preferredExtension),
           exportSession.supportedFileTypes.contains(preferredType) {
            return .assetExport(
                fileExtension: preferredExtension,
                outputFileType: preferredType
            )
        }

        if exportSession.supportedFileTypes.contains(.m4a) {
            return .assetExport(
                fileExtension: "m4a",
                outputFileType: .m4a
            )
        }

        guard let supportedType = exportSession.supportedFileTypes.first,
              let supportedExtension = fileExtension(for: supportedType)
        else {
            throw PurchasedITunesTrackCopyError.exportSessionUnavailable
        }

        return .assetExport(
            fileExtension: supportedExtension,
            outputFileType: supportedType
        )
    }

    /// Возвращает расширение исходного URL, а если оно неизвестно — m4a.
    private func preferredFileExtension(
        for sourceURL: URL
    ) -> String {
        let extensionValue = sourceURL.pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return extensionValue.isEmpty ? "m4a" : extensionValue
    }

    /// Собирает имя файла в формате Artist - Title без запрещённых символов.
    private func displayFileBaseName(
        for track: PurchasedITunesPlayableTrack
    ) -> String {
        let title = sanitizedFileNameComponent(
            track.title ?? track.fileName
        )
        let artist = sanitizedFileNameComponent(
            track.artist ?? ""
        )

        let baseName: String
        if artist.isEmpty {
            baseName = title
        } else {
            baseName = "\(artist) - \(title)"
        }

        return baseName.isEmpty ? "iTunes Track" : baseName
    }

    /// Убирает символы, которые нельзя безопасно использовать в имени файла.
    private func sanitizedFileNameComponent(
        _ value: String
    ) -> String {
        let forbidden = CharacterSet(
            charactersIn: "/\\?%*|\"<>:\u{0000}"
        )
        let scalars = value.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? " " : String(scalar)
        }

        return scalars
            .joined()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
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

    // MARK: - File writing

    /// Записывает исходный iTunes-ассет во временный файл.
    private func writeSource(
        _ track: PurchasedITunesPlayableTrack,
        toTemporaryURL temporaryURL: URL,
        using plan: SourceWritePlan
    ) async throws {
        switch plan {
        case .fileCopy:
            try copyFileURLSource(
                track.assetURL,
                to: temporaryURL
            )

        case .assetExport(_, let outputFileType):
            try await exportMediaLibrarySource(
                track.assetURL,
                to: temporaryURL,
                outputFileType: outputFileType,
                metadata: makeExportMetadata(for: track)
            )
        }
    }

    /// Копирует обычный file URL без обращения к BookmarkResolver.
    private func copyFileURLSource(
        _ sourceURL: URL,
        to temporaryURL: URL
    ) throws {
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try FileManager.default.copyItem(
                at: sourceURL,
                to: temporaryURL
            )
        } catch {
            throw PurchasedITunesTrackCopyError.copyFailed(underlying: error)
        }
    }

    /// Экспортирует media-library URL через AVAssetExportSession без перекодирования.
    private func exportMediaLibrarySource(
        _ sourceURL: URL,
        to temporaryURL: URL,
        outputFileType: AVFileType,
        metadata: [AVMetadataItem]
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw PurchasedITunesTrackCopyError.exportSessionUnavailable
        }

        // Media-library export не переносит runtime-теги автоматически,
        // поэтому явно записываем common metadata в создаваемый файл.
        exportSession.metadata = metadata

        do {
            try await exportSession.export(
                to: temporaryURL,
                as: outputFileType
            )
        } catch {
            throw PurchasedITunesTrackCopyError.exportFailed(
                underlying: error
            )
        }
    }

    /// Собирает common metadata для AVAssetExportSession из runtime-данных iTunes-трека.
    private func makeExportMetadata(
        for track: PurchasedITunesPlayableTrack
    ) -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []

        if let titleItem = makeStringMetadataItem(
            identifier: .commonIdentifierTitle,
            value: track.title
        ) {
            metadata.append(titleItem)
        }

        if let artistItem = makeStringMetadataItem(
            identifier: .commonIdentifierArtist,
            value: track.artist
        ) {
            metadata.append(artistItem)
        }

        if let albumItem = makeStringMetadataItem(
            identifier: .commonIdentifierAlbumName,
            value: track.album
        ) {
            metadata.append(albumItem)
        }

        if let artworkItem = makeArtworkMetadataItem(
            artworkData: track.artworkData
        ) {
            metadata.append(artworkItem)
        }

        return metadata
    }

    /// Создаёт строковый common metadata item и пропускает пустые значения.
    private func makeStringMetadataItem(
        identifier: AVMetadataIdentifier,
        value: String?
    ) -> AVMetadataItem? {
        guard let value else { return nil }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmedValue.isEmpty == false else { return nil }

        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = trimmedValue as NSString

        return item.copy() as? AVMetadataItem
    }

    /// Создаёт common artwork metadata item из raw-данных обложки.
    private func makeArtworkMetadataItem(
        artworkData: Data?
    ) -> AVMetadataItem? {
        guard let artworkData, artworkData.isEmpty == false else {
            return nil
        }

        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierArtwork
        item.value = artworkData as NSData

        return item.copy() as? AVMetadataItem
    }

    /// Маппит понятное расширение на AVFileType.
    private func avFileType(
        for fileExtension: String
    ) -> AVFileType? {
        switch fileExtension.lowercased() {
        case "m4a":
            return .m4a
        case "mp4":
            return .mp4
        case "mov":
            return .mov
        case "caf":
            return .caf
        default:
            return nil
        }
    }

    /// Возвращает расширение файла для AVFileType, если оно поддержано приложением.
    private func fileExtension(
        for fileType: AVFileType
    ) -> String? {
        switch fileType {
        case .m4a:
            return "m4a"
        case .mp4:
            return "mp4"
        case .mov:
            return "mov"
        case .caf:
            return "caf"
        default:
            return nil
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
