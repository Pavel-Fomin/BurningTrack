//
//  TrackRuntimeSnapshotBuilder.swift
//  TrackList
//
//  Единый сборщик каноничного runtime snapshot трека.
//  Роль:
//  - получить доступ к файлу трека по trackId
//  - прочитать расширенные теги для detail-экрана
//  - прочитать runtime-данные (duration, artworkData)
//  - собрать один TrackRuntimeSnapshot
//
//  Важно:
//  - не обновляет UI
//  - не публикует события
//  - не хранит состояние
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

final class TrackRuntimeSnapshotBuilder {

    // MARK: - Singleton

    static let shared = TrackRuntimeSnapshotBuilder() /// Общий экземпляр сборщика snapshot

    // MARK: - Init

    private init() {}

    // MARK: - Build

    /// Собирает каноничный runtime snapshot трека по его идентификатору.
    /// Использует существующие слои проекта:
    /// - BookmarkResolver
    /// - TLTagLibFile
    /// - TrackMetadataCacheManager
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: Готовый TrackRuntimeSnapshot или nil, если URL не удалось разрешить
    func buildSnapshot(forTrackId trackId: UUID) async -> TrackRuntimeSnapshot? {

        // Пытаемся получить URL файла по существующему bookmark pipeline.
        guard let url = await BookmarkResolver.url(forTrack: trackId) else { return nil }

        // Открываем scoped-доступ для чтения файла.
        let hasAccess = url.startAccessingSecurityScopedResource()

        defer {

            if hasAccess { url.stopAccessingSecurityScopedResource() }

        }

        // Имя файла берём из актуального URL.
        let fileName = url.lastPathComponent

        // Доступность определяем по фактическому наличию файла.
        let isAvailable = FileManager.default.fileExists(atPath: url.path)

        // Расширенные теги читаем напрямую через TagLib reader.
        // Builder теперь сам собирает TrackRuntimeSnapshot.
        let tagFile = TLTagLibFile(fileURL: url)
        let parsedMetadata = tagFile.readMetadata()

        // Runtime-данные читаем через существующий metadata cache manager.
        let cachedMetadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)

        return TrackRuntimeSnapshot(
            trackId: trackId,                         /// Идентификатор трека
            fileName: fileName,                       /// Имя файла
            isAvailable: isAvailable,                 /// Доступность файла

            title: parsedMetadata?.title,             /// Название трека
            artist: parsedMetadata?.artist,           /// Основной исполнитель
            album: parsedMetadata?.album,             /// Альбом
            albumArtist: nil,                         /// Исполнитель альбома

            genre: parsedMetadata?.genre,             /// Жанр
            comment: parsedMetadata?.comment,         /// Комментарий

            composer: nil,                            /// Композитор
            conductor: nil,                           /// Дирижёр
            lyricist: nil,                            /// Автор текста
            remixer: nil,                             /// Автор ремикса

            grouping: nil,                            /// Поле группировки
            bpm: nil,                                 /// Темп трека
            musicalKey: nil,                          /// Музыкальная тональность

            trackNumber: nil,                         /// Номер трека
            totalTracks: nil,                         /// Общее количество треков
            discNumber: nil,                          /// Номер диска
            totalDiscs: nil,                          /// Общее количество дисков

            year: parsedMetadata?.year,               /// Год выпуска
            date: nil,                                /// Полная дата

            publisherOrLabel: parsedMetadata?.publisher, /// Лейбл или издатель
            copyright: nil,                           /// Copyright
            encodedBy: nil,                           /// Кем закодирован файл
            isrc: nil,                                /// Международный код записи

            duration: cachedMetadata?.duration,       /// Длительность трека
            artworkData: cachedMetadata?.artworkData, /// Обложка в raw data
            updatedAt: Date()                         /// Время сборки snapshot
        )
    }
}
