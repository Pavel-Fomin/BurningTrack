//
//  PioneerDeckExportService.swift
//  TrackList
//
//  App-level сервис тестового Pioneer USB Export.
//

import Foundation

/// Ошибки тестового app-level экспорта Pioneer USB.
enum PioneerDeckExportServiceError: LocalizedError {
    /// В треклисте нет треков для записи.
    case emptyTrackList

    /// Не удалось получить исходный URL аудиофайла.
    case sourceFileURLUnavailable(fileName: String)

    /// Исходный файл не найден по восстановленному URL.
    case sourceFileNotFound(fileName: String)

    /// Пользовательское описание ошибки для toast-слоя.
    var errorDescription: String? {
        switch self {
        case .emptyTrackList:
            return "Нет треков для Pioneer USB Export"
        case let .sourceFileURLUnavailable(fileName):
            return "Не удалось определить исходный файл трека «\(fileName)»"
        case let .sourceFileNotFound(fileName):
            return "Исходный файл трека «\(fileName)» не найден"
        }
    }
}

/// Сервис собирает PioneerDeckExport из одного TrackList и пишет структуру PIONEER в выбранную папку.
final class PioneerDeckExportService {
    /// Writer структуры PIONEER.
    private let writer: PioneerDeckUSBExportWriter

    /// Файловая система для проверки исходных файлов.
    private let fileManager: FileManager

    /// Асинхронный resolver исходного URL трека через bookmark/registry слой приложения.
    private let sourceURLResolver: (UUID) async -> URL?

    /// Создаёт сервис тестового Pioneer USB Export.
    init(
        writer: PioneerDeckUSBExportWriter = PioneerDeckUSBExportWriter(),
        fileManager: FileManager = .default,
        sourceURLResolver: @escaping (UUID) async -> URL? = { trackId in
            await BookmarkResolver.url(forTrack: trackId)
        }
    ) {
        self.writer = writer
        self.fileManager = fileManager
        self.sourceURLResolver = sourceURLResolver
    }

    /// Экспортирует один TrackList в выбранную пользователем директорию.
    func export(
        trackList: TrackList,
        to destinationURL: URL
    ) async throws {
        guard trackList.tracks.isEmpty == false else {
            throw PioneerDeckExportServiceError.emptyTrackList
        }

        let destinationAccess = SecurityScopedURLAccess(url: destinationURL)
        defer { destinationAccess.stop() }

        var sourceAccesses: [SecurityScopedURLAccess] = []
        defer {
            sourceAccesses.reversed().forEach { $0.stop() }
        }

        let sourceTracks = try await makeSourceTracks(
            from: trackList.tracks,
            sourceAccesses: &sourceAccesses
        )
        let sourcePlaylist = PioneerDeckSourcePlaylist(
            sourcePlaylistId: trackList.id,
            name: trackList.name,
            tracks: sourceTracks
        )
        let export = try PioneerDeckExportFactory.makeExport(from: [sourcePlaylist])

        try writer.write(export: export, to: destinationURL)
    }

    /// Собирает source-модели и удерживает security-scoped доступ к исходным файлам до конца записи.
    private func makeSourceTracks(
        from tracks: [Track],
        sourceAccesses: inout [SecurityScopedURLAccess]
    ) async throws -> [PioneerDeckSourceTrack] {
        var result: [PioneerDeckSourceTrack] = []

        for track in tracks {
            guard let sourceURL = await sourceURLResolver(track.trackId) else {
                throw PioneerDeckExportServiceError.sourceFileURLUnavailable(fileName: track.fileName)
            }

            let sourceAccess = SecurityScopedURLAccess(url: sourceURL)
            sourceAccesses.append(sourceAccess)

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw PioneerDeckExportServiceError.sourceFileNotFound(fileName: track.fileName)
            }

            result.append(
                PioneerDeckSourceTrack(
                    sourceTrackId: track.trackId,
                    title: track.title,
                    artist: track.artist,
                    duration: track.duration,
                    fileName: track.fileName,
                    sourceFileURL: sourceURL
                )
            )
        }

        return result
    }
}

/// Удерживает security-scoped доступ к URL на время операции.
private final class SecurityScopedURLAccess {
    /// URL, для которого открыт доступ.
    private let url: URL

    /// Был ли доступ реально открыт.
    private let didStartAccessing: Bool

    /// Открывает доступ к URL, если система требует security scope.
    init(url: URL) {
        self.url = url
        self.didStartAccessing = url.startAccessingSecurityScopedResource()
    }

    /// Закрывает доступ, если он был открыт.
    func stop() {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
