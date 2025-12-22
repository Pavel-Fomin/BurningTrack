//
//  AppCommandExecutor.swift
//  TrackList
//
//  Исполнитель команд пользовательских действий.
//
//  Отвечает за выполнение бизнес-сценариев:
//  - операции с файлами треков
//  - операции с треклистами
//
//  НЕ содержит UI-логики.
//  НЕ знает про SwiftUI, SheetManager и навигацию.
//  Работает поверх существующих менеджеров и реестров.
//
//  Created by Pavel Fomin on 20.12.2025.
//

import Foundation

/// Единая точка исполнения команд пользовательских действий.
///
/// Command-based UI Architecture:
/// - UI (sheet) инициирует команду
/// - AppCommandExecutor выполняет сценарий
/// - UI обновляется реактивно от состояния
///
actor AppCommandExecutor {

    // MARK: - Singleton

    static let shared = AppCommandExecutor()
    private init() {}

    // MARK: - Операции с файлами треков
   
    /// Перемещает трек в другую папку фонотеки
    /// - Parameters:
    /// - trackId: Идентификатор трека
    /// - folderId: Идентификатор целевой папки
    /// - playerManager: PlayerManager для проверки занятости трека
    /// Реализация будет перенесена из LibraryFileManager на следующем этапе рефакторинга.
    func moveTrack(
        trackId: UUID,
        toFolder folderId: UUID,
        using playerManager: PlayerManager
    ) async throws {

        try await LibraryFileManager.shared.moveTrack(
            id: trackId,
            toFolder: folderId,
            using: playerManager
        )
        NotificationCenter.default.post(name: .trackDidMove,object: trackId)
    }
    
    // Переименовывает файл трека
    /// - Parameters:
    /// - trackId: Идентификатор трека
    /// - newFileName: Новое имя файла (с расширением)
    /// - playerManager: PlayerManager для проверки занятости трека
    func renameTrack(
        trackId: UUID,
        to newFileName: String,
        using playerManager: PlayerManager
    ) async throws {
        fatalError("Команда renameTrack не реализована")
    }

    // MARK: - Операции с треклистами
   
    // Добавляет трек в треклист
    /// - Parameters:
    /// - trackId: Идентификатор трека
    /// - trackListId: Идентификатор треклиста
    /// Реализация будет перенесена из AddToTrackListSheet
    func addTrackToTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws {

        /// 1. Резолвим URL трека через bookmark
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            throw NSError(
                domain: "AddToTrackList",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось получить URL трека"]
            )
        }

        /// 2. Формируем модель Track для треклиста
        let imported = Track(
            id: trackId,
            title: nil,
            artist: nil,
            duration: 0,
            fileName: url.lastPathComponent,
            isAvailable: true
        )

        // 3. Загружаем треклист и добавляем трек
        var list = TrackListManager.shared.getTrackListById(trackListId)
        list.tracks.append(imported)

        // 4. Сохраняем обновлённый треклист
        TrackListManager.shared.saveTracks(list.tracks, for: list.id)
    }
    
    // Создаёт новый треклист
    /// - Parameter name: Имя треклиста
    func createTrackList(
        name: String
    ) async throws {

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrackListManager.shared.validateName(trimmed) else { return }

        // PlaylistManager — @MainActor → нужен await
        let playerTracks = await PlaylistManager.shared.tracks

        let tracks: [Track] = playerTracks.map {
            Track(
                id: $0.id,
                title: $0.title,
                artist: $0.artist,
                duration: $0.duration,
                fileName: $0.fileName,
                isAvailable: $0.isAvailable
            )
        }

        _ = TrackListsManager.shared.createTrackList(
            from: tracks,
            withName: trimmed
        )
    }

    // Переименовывает треклист
    /// - Parameters:
    /// - trackListId: Идентификатор треклиста
    /// - newName: Новое имя треклиста
    ///
    func renameTrackList(
        trackListId: UUID,
        newName: String
    ) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrackListManager.shared.validateName(trimmed) else { return }

        TrackListsManager.shared.renameTrackList(
            id: trackListId,
            to: trimmed
        )
    }
}
