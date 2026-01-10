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

import SwiftUI
import Foundation
import UIKit

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
    
    // MARK: - Переместить трек
    
    func moveTrack(
        trackId: UUID,
        toFolder folderId: UUID,
        using playerManager: PlayerManager
    ) async throws {

        // 1. Перемещение файла
        try await LibraryFileManager.shared.moveTrack(
            id: trackId,
            toFolder: folderId,
            using: playerManager
        )

        // 2. Резолв URL (только для тоста)
        guard let url = await BookmarkResolver.url(forTrack: trackId) else { return }

        // 3. Метаданные трека
        let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)

        // 4. Имя папки назначения (ЕДИНСТВЕННЫЙ валидный способ)
        let folderName = await TrackRegistry.shared
            .allFolders()
            .first(where: { $0.id == folderId })?
            .name ?? "папку"

        // 5. ToastEvent
        let event = ToastEvent.trackMovedInLibrary(
            title: metadata?.title ?? url.lastPathComponent,
            artist: metadata?.artist ?? "",
            artwork: metadata.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            },
            folderName: folderName
        )

        // 6. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: -  Переименовать файл
    
    func renameTrack(
        trackId: UUID,
        to newFileName: String,
        using playerManager: PlayerManager
    ) async throws {
        fatalError("Команда renameTrack не реализована")
    }
    
   
    // MARK: - Добавить в треклист
    
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
        
        /// 3. Загружаем треклист и добавляем трек
        var list = TrackListManager.shared.getTrackListById(trackListId)
        list.tracks.append(imported)
        
        /// 4. Сохраняем обновлённый треклист
        TrackListManager.shared.saveTracks(list.tracks, for: list.id)
        
        /// 5. Загружаем метаданные трека
        let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)

        /// 6. ToastEvent
        let event = ToastEvent.trackAddedToTrackList(
            title: metadata?.title ?? imported.fileName,
            artist: metadata?.artist ?? "",
            artwork: metadata.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            },
            trackListName: list.name
        )

        /// 7. Показ тоста — строго MainActor
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    // MARK: - Создать треклист
    
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
        
        let created = TrackListsManager.shared.createTrackList(
            from: tracks,
            withName: trimmed
        )
        
        let event = ToastEvent.trackListSaved(name: created.name)
        
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Переименовать треклист
    
    func renameTrackList(
        trackListId: UUID,
        newName: String
    ) async throws {

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrackListManager.shared.validateName(trimmed) else { return }

        // 1. Переименование
        TrackListsManager.shared.renameTrackList(
            id: trackListId,
            to: trimmed
        )

        // 2. ToastEvent
        let event = ToastEvent.trackListRenamed(newName: trimmed)

        // 3. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    // MARK: - Удалить трек из треклиста
    
    func removeTrackFromTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws {

        /// 1. Получаем треклист
        var list = TrackListManager.shared.getTrackListById(trackListId)

        /// 2. Удаляем трек
        list.tracks.removeAll { $0.id == trackId }

        /// 3. Сохраняем
        TrackListManager.shared.saveTracks(list.tracks, for: list.id)

        /// 4. Резолв URL (ТОЛЬКО для тоста)
        guard let url = await BookmarkResolver.url(forTrack: trackId) else { return }

        /// 5. Метаданные
        let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)

        /// 6. ToastEvent
        let event = ToastEvent.trackRemovedFromTrackList(
            title: metadata?.title ?? url.lastPathComponent,
            artist: metadata?.artist ?? "",
            artwork: metadata.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )

        /// 7. Показ тоста
        await MainActor.run { ToastManager.shared.handle(event)
        }
    }
    
    // MARK: - Добавить в плеер
    
    /// Добавляет трек в плеер
    func addTrackToPlayer(trackId: UUID) async throws {
        
        /// 1. Резолвим URL
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            throw NSError(
                domain: "AddToPlayer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось получить URL трека"]
            )
        }
        
        /// 2. Загружаем метаданные
        let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)
        
        /// 3. Формируем PlayerTrack
        let track = PlayerTrack(
            id: trackId,
            title: metadata?.title,
            artist: metadata?.artist,
            duration: metadata?.duration ?? 0,
            fileName: url.lastPathComponent,
            isAvailable: true
        )
        
        /// 4. Мутация плеера — строго на MainActor
        await MainActor.run {
            PlaylistManager.shared.tracks.append(track)
            PlaylistManager.shared.saveToDisk()
        }
        
        /// 5. ToastEvent
        let event = ToastEvent.trackAddedToPlayer(
            title: metadata?.title ?? track.fileName,
            artist: metadata?.artist ?? "",
            artwork: metadata.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )
        
        await MainActor.run { ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Удалить трек из плеера

    func removeTrackFromPlayer(trackId: UUID) async throws {

        // 1. Резолв URL (только для тоста)
        let url = await BookmarkResolver.url(forTrack: trackId)

        // 2. Метаданные
        let metadata: TrackMetadataCacheManager.CachedMetadata?
        if let url {
            metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url)
        } else {
            metadata = nil
        }

        // 3. Мутация плеера — строго MainActor
        await MainActor.run {
            PlaylistManager.shared.tracks.removeAll { $0.id == trackId }
            PlaylistManager.shared.saveToDisk()
        }

        // 4. ToastEvent
        let event = ToastEvent.trackRemovedFromPlayer(
            title: metadata?.title ?? url?.lastPathComponent ?? "Трек",
            artist: metadata?.artist ?? "",
            artwork: metadata.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )

        // 5. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Очистить плеер

    func clearPlayer() async {

        // 1. Очистка — строго MainActor
        await MainActor.run {
            PlaylistManager.shared.tracks.removeAll()
            PlaylistManager.shared.saveToDisk()
        }

        // 2. ToastEvent
        await MainActor.run {
            ToastManager.shared.handle(.playerCleared)
        }
    }
}
    
  
