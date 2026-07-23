//
//  PurchasedITunesAssetWriter.swift
//  TrackList
//
//  Общая запись runtime-ассета из системной медиатеки iOS.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation
@preconcurrency import AVFoundation

/// Содержит только runtime-данные iTunes-трека, необходимые файловой операции.
struct PurchasedITunesAsset: Equatable, Sendable {
    /// Стабильный идентификатор трека внутри приложения.
    let trackID: UUID
    /// Готовый URL MediaPlayer, который нельзя восстанавливать через BookmarkResolver.
    let sourceURL: URL
    /// Название трека из системной медиатеки.
    let title: String?
    /// Запасное имя, если системное название отсутствует.
    let fallbackFileName: String
    /// Имя артиста для итогового имени и metadata.
    let artist: String?
    /// Название альбома для metadata.
    let album: String?
    /// Runtime-данные обложки для metadata.
    let artworkData: Data?

    /// Создаёт файловый источник из адаптера экрана «Куплено в iTunes».
    init(track: PurchasedITunesPlayableTrack) {
        self.trackID = track.trackId
        self.sourceURL = track.assetURL
        self.title = track.title
        self.fallbackFileName = track.fileName
        self.artist = track.artist
        self.album = track.album
        self.artworkData = track.artworkData
    }

    /// Извлекает отдельный iTunes-источник из общей transport-модели экспорта.
    init?(track: Track) {
        guard track.source == .purchasedITunes,
              let sourceURL = track.assetURL else {
            return nil
        }

        self.trackID = track.trackId
        self.sourceURL = sourceURL
        self.title = track.title
        self.fallbackFileName = track.fileName
        self.artist = track.artist
        self.album = track.album
        self.artworkData = track.artworkData
    }
}

/// Ошибки общего механизма записи iTunes-ассета.
enum PurchasedITunesAssetWriterError: Error {
    /// Runtime-модель не содержит готового assetURL MediaPlayer.
    case sourceUnavailable
    /// Система не смогла создать passthrough-сессию для media-library URL.
    case exportSessionUnavailable
    /// AVAssetExportSession завершилась ошибкой.
    case exportFailed(underlying: Error?)
    /// Размер обычного file URL нельзя представить в диапазоне Int64.
    case sourceSizeUnavailable
    /// Обычный file URL не удалось скопировать в назначение.
    case copyFailed(underlying: Error)
}

/// Безопасно передаёт только команду отмены AVFoundation в Sendable-замыкание.
private final class PurchasedITunesAssetExportCancellation: @unchecked Sendable {
    /// Сессия живёт до завершения операции или вызова системной отмены.
    private let exportSession: AVAssetExportSession

    /// Сохраняет сессию, которую создал текущий вызов writer-а.
    init(exportSession: AVAssetExportSession) {
        self.exportSession = exportSession
    }

    /// AVFoundation принимает отмену из cancellation handler текущей задачи.
    func cancel() {
        exportSession.cancelExport()
    }
}

/// Записывает iTunes-ассет напрямую из assetURL без BookmarkResolver.
///
/// File URL копируется существующим порционным копировщиком, а media-library URL
/// экспортируется через AVAssetExportSession без перекодирования.
struct PurchasedITunesAssetWriter {

    /// План фиксирует расширение и способ записи до подготовки итогового URL.
    struct WritePlan {
        /// Фактическое расширение создаваемого файла.
        let fileExtension: String
        /// Низкоуровневый способ записи выбранного системного URL.
        fileprivate let method: Method

        /// Разделяет обычное копирование и passthrough-экспорт MediaPlayer.
        fileprivate enum Method {
            case fileCopy
            case assetExport(outputFileType: AVFileType)
        }
    }

    /// Порционный копировщик переиспользуется для обычных file URL.
    private let fileCopier: ExportFileCopier

    /// Создаёт writer с production- или тестовым порционным копировщиком.
    init(fileCopier: ExportFileCopier = ExportFileCopier()) {
        self.fileCopier = fileCopier
    }

    /// Определяет фактический способ записи и расширение итогового файла.
    func makeWritePlan(
        for asset: PurchasedITunesAsset
    ) throws -> WritePlan {
        if asset.sourceURL.isFileURL {
            return WritePlan(
                fileExtension: preferredFileExtension(for: asset.sourceURL),
                method: .fileCopy
            )
        }

        let sourceAsset = AVURLAsset(url: asset.sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: sourceAsset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw PurchasedITunesAssetWriterError.exportSessionUnavailable
        }

        let preferredExtension = preferredFileExtension(for: asset.sourceURL)
        if let preferredType = avFileType(for: preferredExtension),
           exportSession.supportedFileTypes.contains(preferredType) {
            return WritePlan(
                fileExtension: preferredExtension,
                method: .assetExport(outputFileType: preferredType)
            )
        }

        if exportSession.supportedFileTypes.contains(.m4a) {
            return WritePlan(
                fileExtension: "m4a",
                method: .assetExport(outputFileType: .m4a)
            )
        }

        guard let supportedType = exportSession.supportedFileTypes.first,
              let supportedExtension = fileExtension(for: supportedType) else {
            throw PurchasedITunesAssetWriterError.exportSessionUnavailable
        }

        return WritePlan(
            fileExtension: supportedExtension,
            method: .assetExport(outputFileType: supportedType)
        )
    }

    /// Записывает ассет по заранее подготовленному плану и удаляет неполный результат.
    func write(
        _ asset: PurchasedITunesAsset,
        to destinationURL: URL,
        using plan: WritePlan,
        shouldCancel: () -> Bool = { false },
        onBytesWritten: (Int64) -> Void = { _ in }
    ) async throws {
        try throwIfCancelled(shouldCancel)

        do {
            switch plan.method {
            case .fileCopy:
                let byteCount = try fileByteCount(at: asset.sourceURL)
                try fileCopier.copy(
                    from: asset.sourceURL,
                    to: destinationURL,
                    expectedByteCount: byteCount,
                    shouldCancel: shouldCancel,
                    onBytesCopied: onBytesWritten
                )

            case .assetExport(let outputFileType):
                try await exportMediaLibrarySource(
                    asset,
                    to: destinationURL,
                    outputFileType: outputFileType,
                    fileExtension: plan.fileExtension,
                    shouldCancel: shouldCancel,
                    onBytesWritten: onBytesWritten
                )
            }

            try throwIfCancelled(shouldCancel)
        } catch is CancellationError {
            try? removeFileIfPresent(at: destinationURL)
            throw CancellationError()
        } catch let error as PurchasedITunesAssetWriterError {
            try? removeFileIfPresent(at: destinationURL)
            throw error
        } catch {
            try? removeFileIfPresent(at: destinationURL)
            throw PurchasedITunesAssetWriterError.copyFailed(
                underlying: error
            )
        }
    }

    /// Собирает безопасную основу имени в существующем формате Artist - Title.
    static func displayFileBaseName(
        for asset: PurchasedITunesAsset
    ) -> String {
        let title = sanitizedFileNameComponent(
            asset.title ?? asset.fallbackFileName
        )
        let artist = sanitizedFileNameComponent(asset.artist ?? "")

        let baseName: String
        if artist.isEmpty {
            baseName = title
        } else {
            baseName = "\(artist) - \(title)"
        }

        return baseName.isEmpty ? "iTunes Track" : baseName
    }

    /// Добавляет к подготовленной основе фактическое расширение плана записи.
    static func exportFileName(
        baseName: String,
        using plan: WritePlan
    ) -> String {
        URL(fileURLWithPath: baseName)
            .appendingPathExtension(plan.fileExtension)
            .lastPathComponent
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

    /// Убирает символы, которые нельзя безопасно использовать в имени файла.
    private static func sanitizedFileNameComponent(
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

    /// Экспортирует media-library URL через AVAssetExportSession без перекодирования.
    private func exportMediaLibrarySource(
        _ asset: PurchasedITunesAsset,
        to destinationURL: URL,
        outputFileType: AVFileType,
        fileExtension: String,
        shouldCancel: () -> Bool,
        onBytesWritten: (Int64) -> Void
    ) async throws {
        let sourceAsset = AVURLAsset(url: asset.sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: sourceAsset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw PurchasedITunesAssetWriterError.exportSessionUnavailable
        }

        // Media-library export не переносит runtime-теги автоматически,
        // поэтому явно записываем common metadata в создаваемый файл.
        exportSession.metadata = makeExportMetadata(for: asset)

        // AVFoundation сначала материализует media-library URL в локальный
        // временный файл. После этого общий порционный copier безопасно пишет
        // результат в iCloud Drive, USB или другой выбранный file provider.
        let materializedURL = try makeTemporaryURL(
            fileExtension: fileExtension
        )
        let cancellation = PurchasedITunesAssetExportCancellation(
            exportSession: exportSession
        )
        defer {
            try? removeFileIfPresent(at: materializedURL)
        }

        do {
            try await withTaskCancellationHandler {
                try await exportSession.export(
                    to: materializedURL,
                    as: outputFileType
                )
            } onCancel: {
                cancellation.cancel()
            }
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw PurchasedITunesAssetWriterError.exportFailed(
                underlying: error
            )
        }

        try throwIfCancelled(shouldCancel)

        do {
            let byteCount = try fileByteCount(at: materializedURL)
            try fileCopier.copy(
                from: materializedURL,
                to: destinationURL,
                expectedByteCount: byteCount,
                shouldCancel: shouldCancel,
                onBytesCopied: onBytesWritten
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PurchasedITunesAssetWriterError.copyFailed(
                underlying: error
            )
        }
    }

    /// Собирает common metadata для AVAssetExportSession из runtime-данных трека.
    private func makeExportMetadata(
        for asset: PurchasedITunesAsset
    ) -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []

        if let titleItem = makeStringMetadataItem(
            identifier: .commonIdentifierTitle,
            value: asset.title
        ) {
            metadata.append(titleItem)
        }

        if let artistItem = makeStringMetadataItem(
            identifier: .commonIdentifierArtist,
            value: asset.artist
        ) {
            metadata.append(artistItem)
        }

        if let albumItem = makeStringMetadataItem(
            identifier: .commonIdentifierAlbumName,
            value: asset.album
        ) {
            metadata.append(albumItem)
        }

        if let artworkItem = makeArtworkMetadataItem(
            artworkData: asset.artworkData
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

    /// Создаёт common artwork metadata item из runtime-данных обложки.
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

    /// Определяет размер обычного file URL для порционного копирования.
    private func fileByteCount(
        at sourceURL: URL
    ) throws -> Int64 {
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try sourceURL.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]
        )
        guard values.isRegularFile == true else {
            throw ExportFileCopierError.sourceIsNotRegularFile
        }

        if let fileSize = values.fileSize {
            return Int64(fileSize)
        }

        let handle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? handle.close() }
        let endOffset = try handle.seekToEnd()
        guard endOffset <= UInt64(Int64.max) else {
            throw PurchasedITunesAssetWriterError.sourceSizeUnavailable
        }
        return Int64(endOffset)
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

    /// Создаёт локальный временный URL для результата AVAssetExportSession.
    private func makeTemporaryURL(
        fileExtension: String
    ) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PurchasedITunesAssetWriter",
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

    /// Проверяет флаг общей отмены и cancellation текущей задачи.
    private func throwIfCancelled(
        _ shouldCancel: () -> Bool
    ) throws {
        if shouldCancel() || Task.isCancelled {
            throw CancellationError()
        }
    }

    /// Удаляет неполный результат, если низкоуровневая операция успела его создать.
    private func removeFileIfPresent(
        at url: URL
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
