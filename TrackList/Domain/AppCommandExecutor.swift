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
    
    // MARK: - Зависимости
    
    private let tagsWriter: TagsWriter = TagLibTagsWriter()
    static let shared = AppCommandExecutor()
    private init() {}
    
    // MARK: - Переместить трек
    
    func moveTrack(
        trackId: UUID,
        toFolder folderId: UUID,
        using playerManager: PlayerManager
    ) async throws {
        
        // 1. Запоминаем старый URL до перемещения.
        let previousURL = await BookmarkResolver.url(forTrack: trackId)
        
        // 2. Перемещение файла
        try await LibraryFileManager.shared.moveTrack(
            id: trackId,
            toFolder: folderId,
            using: playerManager
        )
        
        // 3. Запускаем единый post-update pipeline.
        let updateEvent = await TrackUpdateCoordinator.shared.handleTrackUpdate(
            forTrackId: trackId,
            reason: .fileMoved,
            changedFields: [.fileName],
            previousURL: previousURL
        )
        
        // 4. Имя папки назначения (ЕДИНСТВЕННЫЙ валидный способ)
        let folderName = await TrackRegistry.shared
            .allFolders()
            .first(where: { $0.id == folderId })?
            .name ?? "папку"
        
        // 5. ToastEvent строится из snapshot
        let snapshot = updateEvent?.snapshot
        
        let event = ToastEvent.trackMovedInLibrary(
            title: snapshot?.title ?? snapshot?.fileName ?? "Трек",
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
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
        
        // 1. Запоминаем старый URL до переименования.
        // Это нужно, чтобы после rename сбросить raw-cache и по старому пути.
        let previousURL = await BookmarkResolver.url(forTrack: trackId)
        
        // 2. Переименовываем физический файл и обновляем реестры.
        try await LibraryFileManager.shared.renameTrack(
            id: trackId,
            to: newFileName,
            using: playerManager
        )
        
        // 3. Запускаем единый post-update pipeline.
        let updateEvent = await TrackUpdateCoordinator.shared.handleTrackUpdate(
            forTrackId: trackId,
            reason: .fileRenamed,
            changedFields: [.fileName],
            previousURL: previousURL
        )
        
        // 4. ToastEvent строится из готового snapshot единого контракта.
        let event = ToastEvent.fileRenamed(
            newName: updateEvent?.snapshot.fileName ?? newFileName
        )
        
        // 5. Показ тоста.
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
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
        var list = try TrackListManager.shared.getTrackListById(trackListId)
        list.tracks.append(imported)
        
        /// 4. Сохраняем обновлённый треклист
        guard TrackListManager.shared.saveTracks(list.tracks, for: list.id) else {
            throw TrackListStorageError.saveFailed(trackListId: list.id)
        }
        
        /// 5. Получаем snapshot трека
        let snapshot = await resolveSnapshot(for: trackId)
        
        /// 6. ToastEvent строится из snapshot
        let event = ToastEvent.trackAddedToTrackList(
            title: snapshot?.title ?? imported.fileName,
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
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
        guard TrackListManager.shared.validateName(trimmed) else {
            throw AppError.trackListNameInvalid
        }
        
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
        
        let created = try TrackListsManager.shared.createTrackList(
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
        try TrackListsManager.shared.renameTrackList(
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
        var list = try TrackListManager.shared.getTrackListById(trackListId)
        
        /// 2. Удаляем трек
        list.tracks.removeAll { $0.id == trackId }
        
        /// 3. Сохраняем
        guard TrackListManager.shared.saveTracks(list.tracks, for: list.id) else {
            throw TrackListStorageError.saveFailed(trackListId: list.id)
        }
        
        /// 4. Получаем snapshot трека
        let snapshot = await resolveSnapshot(for: trackId)
        
        /// 5. ToastEvent строится из snapshot
        let event = ToastEvent.trackRemovedFromTrackList(
            title: snapshot?.title ?? "Трек",
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )
        
        /// 6. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    // MARK: - Добавить в плеер
    
    func addTrackToPlayer(trackId: UUID) async throws {
        
        /// 1. Резолвим URL
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            throw NSError(
                domain: "AddToPlayer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось получить URL трека"]
            )
        }
        
        /// 2. Получаем snapshot трека
        let snapshot = await resolveSnapshot(for: trackId)
        
        /// 3. Формируем PlayerTrack
        let track = PlayerTrack(
            id: trackId,
            title: snapshot?.title,
            artist: snapshot?.artist,
            duration: snapshot?.duration ?? 0,
            fileName: snapshot?.fileName ?? url.lastPathComponent,
            isAvailable: true
        )
        
        /// 4. Мутация плеера — строго на MainActor
        await MainActor.run {
            PlaylistManager.shared.tracks.append(track)
            PlaylistManager.shared.saveToDisk()
        }
        
        /// 5. ToastEvent
        let event = ToastEvent.trackAddedToPlayer(
            title: snapshot?.title ?? track.fileName,
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )
        
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Удалить трек из плеера
    
    func removeTrackFromPlayer(trackId: UUID) async throws {
        
        // 1. Получаем snapshot трека (для тоста)
        let snapshot = await resolveSnapshot(for: trackId)
        
        // 2. Мутация плеера — строго MainActor
        await MainActor.run {
            PlaylistManager.shared.tracks.removeAll { $0.id == trackId }
            PlaylistManager.shared.saveToDisk()
        }
        
        // 3. ToastEvent строится из snapshot
        let event = ToastEvent.trackRemovedFromPlayer(
            title: snapshot?.title ?? snapshot?.fileName ?? "Трек",
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )
        
        // 4. Показ тоста
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
    
    
    // MARK: - Обновить теги трека
    
    func updateTrackTags(
        trackId: UUID,
        patch: TagWritePatch,
        artworkAction: ArtworkWriteAction
    ) async throws {

        // 1. Резолв URL трека через bookmark
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            throw TagWriteError.fileNotFound
        }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        // 2. Собираем финальный patch.
        // Текстовые теги уже приходят снаружи,
        // а действие по обложке добавляем здесь.
        var finalPatch = patch

        switch artworkAction {
        case .none:
            break

        case .remove:
            finalPatch.artwork = .remove

        case .replace(let data):
            finalPatch.artwork = .set(
                data: data,
                mime: artworkMimeType(for: data)
            )
        }

        // 3. Запись тегов и обложки
        try await tagsWriter.writeTags(to: url, patch: finalPatch)

        // 4. Единый post-update pipeline
        let changedFields = changedFieldsForTagUpdate(
            patch: finalPatch,
            artworkAction: artworkAction
        )

        let updateReason: TrackUpdateReason = artworkAction == .none
            ? .metadataUpdated
            : .artworkUpdated

        let updateEvent = await TrackUpdateCoordinator.shared.handleTrackUpdate(
            forTrackId: trackId,
            reason: updateReason,
            changedFields: changedFields
        )

        // 5. ToastEvent строится из готового snapshot единого контракта
        let snapshot = updateEvent?.snapshot

        let event = ToastEvent.tagsUpdated(
            title: snapshot?.title ?? url.lastPathComponent,
            artist: snapshot?.artist ?? "",
            artwork: snapshot.flatMap {
                ArtworkProvider.shared.image(
                    trackId: trackId,
                    artworkData: $0.artworkData,
                    purpose: .toast
                ).map { Image(uiImage: $0) }
            }
        )

        // 6. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
}

// MARK: - Helper's

/// Определяет MIME-тип изображения по сигнатуре данных.
/// Сейчас поддерживаем PNG и JPEG.
/// Если формат не распознан, по умолчанию считаем его JPEG.
private func artworkMimeType(for data: Data) -> String {
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return "image/png"
    }

    if data.starts(with: [0xFF, 0xD8, 0xFF]) {
        return "image/jpeg"
    }

    return "image/jpeg"
}

// Собирает набор изменённых полей для события обновления тегов и обложки.
///
/// - Parameters:
///   - patch: Финальный patch записи тегов
///   - artworkAction: Действие с обложкой
/// - Returns: Набор изменённых полей TrackRuntimeSnapshot
private func changedFieldsForTagUpdate(
    patch: TagWritePatch,
    artworkAction: ArtworkWriteAction
) -> Set<TrackChangedField> {
    var changedFields: Set<TrackChangedField> = []

    if patch.title != TagFieldChange<String>.unchanged { changedFields.insert(.title) }
    if patch.artist != TagFieldChange<String>.unchanged { changedFields.insert(.artist) }
    if patch.album != TagFieldChange<String>.unchanged { changedFields.insert(.album) }
    if patch.publisher != TagFieldChange<String>.unchanged { changedFields.insert(.publisherOrLabel) }
    if patch.genre != TagFieldChange<String>.unchanged { changedFields.insert(.genre) }
    if patch.comment != TagFieldChange<String>.unchanged { changedFields.insert(.comment) }

    if patch.year != TagFieldChange<Int>.unchanged { changedFields.insert(.year) }
    if patch.trackNumber != TagFieldChange<Int>.unchanged { changedFields.insert(.trackNumber) }
    if patch.bpm != TagFieldChange<Int>.unchanged { changedFields.insert(.bpm) }

    if patch.duration != TagFieldChange<TimeInterval>.unchanged { changedFields.insert(.duration) }

    if artworkAction != .none { changedFields.insert(.artworkData) }

    return changedFields
}

/// Возвращает актуальный snapshot трека.
/// Сначала пытается взять из runtime store, если нет — собирает через builder.
///
/// - Parameter trackId: Идентификатор трека
/// - Returns: TrackRuntimeSnapshot или nil
private func resolveSnapshot(for trackId: UUID) async -> TrackRuntimeSnapshot? {
    
    // 1. Пытаемся взять из store (быстро)
    if let snapshot = TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
        return snapshot
    }
    
    // 2. Fallback: собираем snapshot напрямую
    return await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
}
