//
//  TrackSharePreparationService.swift
//  TrackList
//
//  Подготавливает один аудиофайл для системного меню «Поделиться».
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Ошибки подготовки файла, которые presentation-слой сопоставляет с существующими сообщениями приложения.
enum TrackSharePreparationError: Error {
    /// Закладка локального трека не разрешилась в реальный URL.
    case bookmarkUnavailable
    /// Локальный путь больше не указывает на обычный аудиофайл.
    case localFileUnavailable
    /// Открыть локальный файл для чтения не удалось даже после запроса security-scoped доступа.
    case localFileAccessDenied
    /// iTunes-ассет отсутствует, защищён или система не позволила подготовить экспортируемый файл.
    case purchasedITunesUnavailable
}

/// Подготовленный файл и ресурсы, которые должны жить до закрытия системного меню.
struct PreparedTrackShareFile: Sendable {
    /// URL, который передаётся в UIActivityViewController.
    let fileURL: URL
    /// Идентификатор открытого security-scoped доступа для исходного локального файла.
    let securityScopeID: UUID?
    /// Признак временной копии, созданной только для iTunes-ассета.
    let isTemporaryFile: Bool
}

/// Готовит исходный локальный файл или временную копию iTunes-ассета вне SwiftUI.
///
/// Локальный файл передаётся как есть, а iTunes-ассет материализуется отдельно,
/// потому что служебный ipod-library URL нельзя безопасно передавать стороннему приложению.
actor TrackSharePreparationService {

    // MARK: - Dependencies

    /// Общий writer уже умеет копировать file URL и экспортировать MediaPlayer URL без перекодирования.
    private let purchasedITunesAssetWriter = PurchasedITunesAssetWriter()

    /// Активные security-scoped URL удерживаются до завершения UIActivityViewController.
    private var activeSecurityScopedURLs: [UUID: URL] = [:]

    // MARK: - Local file

    /// Возвращает исходный локальный аудиофайл для системного меню.
    func prepareLocalTrack(
        trackID: UUID
    ) async throws -> PreparedTrackShareFile {
        guard let fileURL = await BookmarkResolver.url(forTrack: trackID) else {
            throw TrackSharePreparationError.bookmarkUnavailable
        }

        let startedSecurityScope = fileURL.startAccessingSecurityScopedResource()

        do {
            try validateReadableRegularFile(at: fileURL)
        } catch {
            if startedSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
            throw error
        }

        let securityScopeID: UUID?
        if startedSecurityScope {
            let identifier = UUID()
            activeSecurityScopedURLs[identifier] = fileURL
            securityScopeID = identifier
        } else {
            securityScopeID = nil
        }

        return PreparedTrackShareFile(
            fileURL: fileURL,
            securityScopeID: securityScopeID,
            isTemporaryFile: false
        )
    }

    // MARK: - Purchased iTunes file

    /// Создаёт временную копию iTunes-трека с тем же правилом имени, что и обычное копирование.
    func preparePurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack
    ) async throws -> PreparedTrackShareFile {
        guard track.isAvailable else {
            throw TrackSharePreparationError.purchasedITunesUnavailable
        }

        let temporaryDirectory: URL
        do {
            temporaryDirectory = try prepareTemporaryDirectory()
        } catch {
            throw TrackSharePreparationError.purchasedITunesUnavailable
        }

        let asset = PurchasedITunesAsset(track: track)

        do {
            let writePlan = try purchasedITunesAssetWriter.makeWritePlan(for: asset)
            let fileName = PurchasedITunesAssetWriter.exportFileName(
                baseName: PurchasedITunesAssetWriter.displayFileBaseName(for: asset),
                using: writePlan
            )
            let destinationURL = temporaryDirectory.appendingPathComponent(
                fileName,
                isDirectory: false
            )

            try await purchasedITunesAssetWriter.write(
                asset,
                to: destinationURL,
                using: writePlan
            )

            return PreparedTrackShareFile(
                fileURL: destinationURL,
                securityScopeID: nil,
                isTemporaryFile: true
            )
        } catch {
            try? removeTemporaryFiles(in: temporaryDirectory)
            // Недоступный, облачный, защищённый и неэкспортируемый iTunes-трек
            // намеренно получают одну пользовательскую причину без технических деталей MediaPlayer.
            throw TrackSharePreparationError.purchasedITunesUnavailable
        }
    }

    // MARK: - Cleanup

    /// Освобождает доступ и удаляет временную копию только после завершения системного меню.
    func finishSharing(
        _ preparedFile: PreparedTrackShareFile
    ) {
        if let securityScopeID = preparedFile.securityScopeID,
           let securityScopedURL = activeSecurityScopedURLs.removeValue(
                forKey: securityScopeID
           ) {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }

        if preparedFile.isTemporaryFile {
            try? FileManager.default.removeItem(at: preparedFile.fileURL)
        }
    }

    // MARK: - Private

    /// Проверяет, что URL указывает на читаемый обычный файл, а не на папку или недоступный placeholder.
    private func validateReadableRegularFile(
        at fileURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TrackSharePreparationError.localFileUnavailable
        }

        do {
            let resourceValues = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey]
            )
            guard resourceValues.isRegularFile == true else {
                throw TrackSharePreparationError.localFileUnavailable
            }
        } catch let error as TrackSharePreparationError {
            throw error
        } catch {
            throw TrackSharePreparationError.localFileAccessDenied
        }

        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw TrackSharePreparationError.localFileAccessDenied
        }
    }

    /// Возвращает изолированный временный каталог и очищает только копии предыдущих отправок.
    private func prepareTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackShare", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        // Новая отправка очищает только собственные старые копии приложения;
        // это не затрагивает фонотеку, SQLite и временные файлы других сценариев.
        try removeTemporaryFiles(in: directory)

        return directory
    }

    /// Удаляет содержимое выделенного каталога, не удаляя сам каталог временной операции.
    private func removeTemporaryFiles(
        in directory: URL
    ) throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
