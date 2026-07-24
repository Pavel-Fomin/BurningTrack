//
//  TrackExportService.swift
//  TrackList
//
//  Фоновый сервис самостоятельного копирования треков в выбранную папку.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Ошибки инфраструктуры, которые нельзя отнести к одному отдельному треку.
enum TrackExportServiceError: Error {
    /// Другая операция экспорта уже использует сервис.
    case exportAlreadyRunning

    /// Выбранный URL не является папкой назначения.
    case destinationIsNotDirectory

    /// Внутри назначения уже существует объект с именем экспортной папки, но это не папка.
    case exportFolderIsNotDirectory

    /// Не удалось подготовить содержимое дочерней экспортной папки.
    case exportFolderPreparationFailed(underlying: Error)

    /// Не удалось определить размер исходного файла.
    case sourceSizeUnavailable

}

/// Потокобезопасный флаг отмены, доступный и actor, и вызывающему UI-коду.
///
/// NSLock используется только для короткого чтения или изменения одного флага;
/// файлы и прогресс через этот объект не проходят.
final class ExportCancellationToken: @unchecked Sendable {

    /// Синхронизирует доступ к флагу отмены.
    private let lock = NSLock()

    /// Признак запрошенной отмены.
    private var cancelled = false

    /// Сбрасывает токен перед началом новой операции.
    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
    }

    /// Устанавливает флаг отмены без ожидания actor.
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    /// Возвращает актуальное состояние отмены.
    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }
}

/// Подготовленный низкоуровневый источник одного экспортируемого файла.
private enum PreparedExportSource {
    /// Обычный файл и его заранее определённый размер.
    case bookmarkFile(sourceURL: URL, byteCount: Int64)
    /// Runtime iTunes-ассет и фактический план его записи.
    case purchasedITunes(
        asset: PurchasedITunesAsset,
        writePlan: PurchasedITunesAssetWriter.WritePlan
    )

    /// Размер известен только для обычного bookmark-файла.
    var byteCount: Int64 {
        switch self {
        case .bookmarkFile(_, let byteCount):
            return byteCount
        case .purchasedITunes:
            return 0
        }
    }

    /// Байтовый прогресс используется только когда источник уже является обычным файлом.
    var supportsByteProgress: Bool {
        switch self {
        case .bookmarkFile:
            return true
        case .purchasedITunes:
            return false
        }
    }
}

/// Готовый к последовательной записи элемент экспортного задания.
private struct PreparedExportItem {
    /// Элемент исходного задания сохраняет исходный порядок.
    let item: ExportJob.Item
    /// Фактический источник, подготовленный без изменения обычного bookmark-пути.
    let source: PreparedExportSource
    /// Полное итоговое имя с расширением для текущего источника.
    let exportFileName: String

    /// Возвращает размер, если источник поддерживает байтовый прогресс.
    var byteCount: Int64 {
        source.byteCount
    }

    /// Показывает, можно ли включить общий байтовый прогресс операции.
    var supportsByteProgress: Bool {
        source.supportsByteProgress
    }
}

/// Управляет подготовкой и последовательным копированием задания экспорта.
///
/// Сервис не знает о UIViewController, picker и SwiftUI. Файловое копирование
/// и подготовка runtime iTunes-ассетов выполняются внутри actor, поэтому
/// MainActor не блокируется длительными операциями экспорта.
actor TrackExportService {

    /// Низкоуровневый копировщик одного файла.
    private let fileCopier: ExportFileCopier

    /// Общий writer обрабатывает assetURL без BookmarkResolver.
    private let purchasedITunesAssetWriter: PurchasedITunesAssetWriter

    /// Флаг активной операции защищён actor.
    private var isExportRunning = false

    /// Токен специально объявлен nonisolated, чтобы отмена могла быть вызвана
    /// синхронно даже во время блока FileHandle, когда actor занят копированием.
    nonisolated private let cancellationToken = ExportCancellationToken()

    /// Создаёт сервис с отдельным копировщиком, который удобно заменить в тестах.
    init(fileCopier: ExportFileCopier = ExportFileCopier()) {
        self.fileCopier = fileCopier
        self.purchasedITunesAssetWriter = PurchasedITunesAssetWriter(
            fileCopier: fileCopier
        )
    }

    /// Отменяет активную операцию без ожидания переключения на actor.
    nonisolated func cancelCurrentExport() {
        cancellationToken.cancel()
    }

    /// Выполняет экспорт в выбранную пользователем папку.
    func export(
        job: ExportJob,
        onProgress: @escaping ExportProgressHandler = { _ in }
    ) async throws -> ExportSummary {
        guard isExportRunning == false else {
            throw TrackExportServiceError.exportAlreadyRunning
        }

        isExportRunning = true
        cancellationToken.reset()
        defer { isExportRunning = false }

        var progress = ExportProgress(
            totalFiles: job.items.count,
            destination: job.destination,
            exportFolder: job.exportFolder,
            rootDestinationName: job.destination.displayName,
            state: .preparing
        )
        onProgress(progress)

        do {
            let destinationStarted = job.destination.folderURL
                .startAccessingSecurityScopedResource()
            defer {
                if destinationStarted {
                    job.destination.folderURL.stopAccessingSecurityScopedResource()
                }
            }

            let destinationValues = try job.destination.folderURL.resourceValues(
                forKeys: [.isDirectoryKey]
            )
            guard destinationValues.isDirectory == true else {
                throw TrackExportServiceError.destinationIsNotDirectory
            }

            let preparedItems = try await prepareItems(
                job.items,
                progress: &progress,
                onProgress: onProgress
            )

            try throwIfCancelled()

            guard preparedItems.isEmpty == false else {
                progress.currentFileName = nil
                progress.state = .failed
                onProgress(progress)
                throw AppError.exportNoFilesPrepared
            }

            // Дочерняя папка готовится только после успешной подготовки хотя
            // бы одного источника, поэтому пустые или недоступные задания не
            // затрагивают уже существующий экспорт.
            let exportDestination = try prepareExportFolder(
                inside: job.destination.folderURL,
                named: job.exportFolderName
            )
            progress.destination = exportDestination
            // Для media-library URL размер заранее неизвестен, поэтому
            // существующий экран автоматически показывает файловый прогресс.
            if preparedItems.allSatisfy(\.supportsByteProgress) {
                progress.totalBytes = preparedItems.reduce(into: Int64(0)) {
                    $0 += $1.byteCount
                }
            } else {
                progress.totalBytes = 0
            }
            progress.state = .copying
            onProgress(progress)

            let summary = try await copyPreparedItems(
                preparedItems,
                progress: &progress,
                onProgress: onProgress
            )
            return summary
        } catch is CancellationError {
            progress.currentFileName = nil
            progress.currentFileBytes = 0
            progress.currentFileCopiedBytes = 0
            progress.state = .cancelled
            onProgress(progress)
            throw CancellationError()
        } catch {
            progress.currentFileName = nil
            progress.currentFileBytes = 0
            progress.currentFileCopiedBytes = 0
            progress.state = .failed
            onProgress(progress)
            throw error
        }
    }

    /// Подготавливает bookmark-файлы и runtime iTunes-ассеты, не останавливаясь на ошибке.
    private func prepareItems(
        _ items: [ExportJob.Item],
        progress: inout ExportProgress,
        onProgress: ExportProgressHandler
    ) async throws -> [PreparedExportItem] {
        var preparedItems: [PreparedExportItem] = []

        for item in items {
            try throwIfCancelled()

            do {
                switch item.source {
                case .bookmark(let trackID):
                    guard let sourceURL = await BookmarkResolver.url(
                        forTrack: trackID
                    ) else {
                        throw ExportFileCopierError.sourceIsNotRegularFile
                    }

                    let byteCount = try fileByteCount(at: sourceURL)
                    preparedItems.append(
                        PreparedExportItem(
                            item: item,
                            source: .bookmarkFile(
                                sourceURL: sourceURL,
                                byteCount: byteCount
                            ),
                            exportFileName: item.exportFileName
                        )
                    )

                case .purchasedITunes(_, let asset):
                    guard let asset else {
                        throw PurchasedITunesAssetWriterError.sourceUnavailable
                    }

                    let writePlan = try purchasedITunesAssetWriter
                        .makeWritePlan(for: asset)
                    let exportFileName = PurchasedITunesAssetWriter
                        .exportFileName(
                            baseName: item.exportFileName,
                            using: writePlan
                        )
                    preparedItems.append(
                        PreparedExportItem(
                            item: item,
                            source: .purchasedITunes(
                                asset: asset,
                                writePlan: writePlan
                            ),
                            exportFileName: exportFileName
                        )
                    )
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                progress.failedFiles.append(
                    ExportFileResult(
                        fileName: item.exportFileName,
                        errorDescription: error.localizedDescription
                    )
                )
                onProgress(progress)
            }
        }

        return preparedItems
    }

    /// Копирует подготовленные файлы и продолжает работу после ошибки отдельного файла.
    private func copyPreparedItems(
        _ items: [PreparedExportItem],
        progress: inout ExportProgress,
        onProgress: ExportProgressHandler
    ) async throws -> ExportSummary {
        var completedBytes: Int64 = 0

        for preparedItem in items {
            try throwIfCancelled()

            #if DEBUG
            ExportDiagnostics.shared.recordCurrentFile(
                number: preparedItem.item.index + 1,
                size: preparedItem.byteCount
            )
            #endif

            progress.currentFileName = preparedItem.exportFileName
            progress.currentFileBytes = preparedItem.byteCount
            progress.currentFileCopiedBytes = 0
            progress.copiedBytes = completedBytes
            onProgress(progress)

            let destinationURL = progress.destination.folderURL
                .appendingPathComponent(
                    preparedItem.exportFileName,
                    isDirectory: false
                )

            do {
                switch preparedItem.source {
                case .bookmarkFile(let sourceURL, let byteCount):
                    try fileCopier.copy(
                        from: sourceURL,
                        to: destinationURL,
                        expectedByteCount: byteCount,
                        shouldCancel: { [cancellationToken] in
                            cancellationToken.isCancelled || Task.isCancelled
                        },
                        onBytesCopied: { copiedBytes in
                            #if DEBUG
                            ExportDiagnostics.shared.recordByteCallback()
                            #endif
                            progress.currentFileCopiedBytes = copiedBytes
                            progress.copiedBytes = completedBytes + copiedBytes
                            onProgress(progress)
                        }
                    )

                case .purchasedITunes(let asset, let writePlan):
                    try await purchasedITunesAssetWriter.write(
                        asset,
                        to: destinationURL,
                        using: writePlan,
                        shouldCancel: { [cancellationToken] in
                            cancellationToken.isCancelled || Task.isCancelled
                        }
                    )
                }

                completedBytes += preparedItem.byteCount
                progress.completedFiles += 1
                progress.copiedBytes = completedBytes
                progress.currentFileName = nil
                progress.currentFileBytes = 0
                progress.currentFileCopiedBytes = 0
                onProgress(progress)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                progress.copiedBytes = completedBytes
                progress.currentFileName = nil
                progress.currentFileBytes = 0
                progress.currentFileCopiedBytes = 0
                progress.failedFiles.append(
                    ExportFileResult(
                        fileName: preparedItem.exportFileName,
                        errorDescription: error.localizedDescription
                    )
                )
                onProgress(progress)
            }
        }

        progress.currentFileName = nil
        progress.currentFileBytes = 0
        progress.currentFileCopiedBytes = 0
        progress.state = progress.failedFiles.isEmpty
            ? .completed
            : .completedWithErrors
        onProgress(progress)

        return ExportSummary(
            completedFiles: progress.completedFiles,
            failedFiles: progress.failedFiles,
            state: progress.state
        )
    }

    /// Определяет размер файла через URL resource values или открытый FileHandle.
    private func fileByteCount(at url: URL) throws -> Int64 {
        let sourceStarted = url.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]
        )
        guard values.isRegularFile == true else {
            throw ExportFileCopierError.sourceIsNotRegularFile
        }

        if let fileSize = values.fileSize {
            return Int64(fileSize)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let endOffset = try handle.seekToEnd()
        guard endOffset <= UInt64(Int64.max) else {
            throw TrackExportServiceError.sourceSizeUnavailable
        }
        return Int64(endOffset)
    }

    /// Создаёт дочернюю экспортную папку или очищает только её содержимое.
    private func prepareExportFolder(
        inside rootFolderURL: URL,
        named requestedName: String
    ) throws -> ExportDestination {
        let folderName = sanitizedExportFolderName(requestedName)
        let exportFolderURL = rootFolderURL.appendingPathComponent(
            folderName,
            isDirectory: true
        )

        let resourceValues = try? exportFolderURL.resourceValues(
            forKeys: [.isDirectoryKey]
        )

        if resourceValues?.isDirectory == true {
            do {
                try removeExportFolderContents(at: exportFolderURL)
            } catch {
                throw TrackExportServiceError.exportFolderPreparationFailed(
                    underlying: error
                )
            }
        } else if (try? exportFolderURL.checkResourceIsReachable()) == true {
            throw TrackExportServiceError.exportFolderIsNotDirectory
        } else {
            do {
                try FileManager.default.createDirectory(
                    at: exportFolderURL,
                    withIntermediateDirectories: false
                )
            } catch {
                throw TrackExportServiceError.exportFolderPreparationFailed(
                    underlying: error
                )
            }
        }

        return ExportDestination(folderURL: exportFolderURL)
    }

    /// Удаляет только непосредственное содержимое папки экспорта.
    ///
    /// Удаление вложенных объектов выполняется FileManager рекурсивно для
    /// каждого элемента, но сама exportFolderURL никогда не передаётся в
    /// removeItem. Родительская папка пользователя также не затрагивается.
    private func removeExportFolderContents(at exportFolderURL: URL) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: exportFolderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for itemURL in contents {
            try FileManager.default.removeItem(at: itemURL)
        }
    }

    /// Преобразует имя экспортной папки в один безопасный компонент URL.
    private func sanitizedExportFolderName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let sanitized = name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard sanitized.isEmpty == false,
              sanitized != ".",
              sanitized != ".." else {
            return "Tracklist"
        }

        return sanitized
    }

    /// Проверяет отмену и Task cancellation между крупными этапами операции.
    private func throwIfCancelled() throws {
        if cancellationToken.isCancelled || Task.isCancelled {
            throw CancellationError()
        }
    }
}
