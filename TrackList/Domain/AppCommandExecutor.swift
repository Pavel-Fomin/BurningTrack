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
        do {
            try await LibraryFileManager.shared.moveTrack(
                id: trackId,
                toFolder: folderId,
                using: playerManager
            )
        } catch let libraryError as LibraryFileError {
            throw appError(from: libraryError, fallback: .fileMoveFailed)
        }
        
        // 3. Запускаем единый post-update pipeline.
        let updateEvent = try await TrackUpdateCoordinator.shared.handleTrackUpdate(
            forTrackId: trackId,
            reason: .fileMoved,
            changedFields: [.fileName],
            previousURL: previousURL
        )
        
        // 4. Имя папки назначения (ЕДИНСТВЕННЫЙ валидный способ)
        let folderName = await TrackRegistry.shared
            .allFolders()
            .first(where: { $0.id == folderId })?
            .name
        
        // 5. ToastEvent строится из snapshot
        let snapshot = updateEvent?.snapshot
        
        let event = ToastEvent.trackMovedInLibrary(
            title: snapshot?.title ?? snapshot?.fileName ?? "",
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

    // MARK: - Копировать iTunes-трек

    /// Принимает выбранную папку назначения для копирования iTunes-трека.
    /// Файловая операция выполняется через отдельный manager, без BookmarkResolver
    /// и файлового metadata cache для исходного iTunes-трека.
    func copyPurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack,
        toFolder folderId: UUID
    ) async throws {
        do {
            let result = try await PurchasedITunesTrackCopyManager.shared.copy(
                track,
                toFolder: folderId
            )

            // После физического копирования используем общий sync-путь фонотеки,
            // чтобы новый файл попал в TrackRegistry и BookmarksRegistry.
            try await LibrarySyncModule.shared.syncRootFolder(
                rootFolderId: result.rootFolderId,
                rootURL: result.rootFolderURL,
                mode: .safe
            )

            let event = trackCopiedFromITunesEvent(
                for: track,
                folderName: result.folderName
            )

            await MainActor.run {
                ToastManager.shared.handle(event)
            }
        } catch {
            print("❌ copyPurchasedITunesTrack failed:", error)
            throw AppError.purchasedITunesCopyFailed
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
        do {
            try await LibraryFileManager.shared.renameTrack(
                id: trackId,
                to: newFileName,
                using: playerManager
            )
        } catch let libraryError as LibraryFileError {
            throw appError(from: libraryError, fallback: .fileRenameFailed)
        }
        
        // 3. Запускаем единый post-update pipeline.
        let updateEvent = try await TrackUpdateCoordinator.shared.handleTrackUpdate(
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

    /// Массово переименовывает файлы треков.
    ///
    /// Метод использует `LibraryFileManager.renameTrack` как атомарную операцию одного файла.
    /// В отличие от одиночного rename-flow, здесь не показывается toast на каждый файл.
    func renameTrackFilesBatch(
        _ commands: [BatchFilenameRenameCommand],
        using playerManager: PlayerManager,
        progress: (@MainActor (_ processed: Int, _ total: Int) -> Void)? = nil
    ) async -> BatchFilenameRenameResult {
        var succeeded: [BatchFilenameRenameSuccess] = []
        var failed: [BatchFilenameRenameFailure] = []
        var successfulUpdates: [TrackUpdateRequest] = []
        var processedCount = 0
        let totalCount = commands.count

        for command in commands {
            do {
                // Запоминаем старый URL до переименования, чтобы post-update pipeline сбросил cache по старому пути.
                let previousURL = await BookmarkResolver.url(forTrack: command.trackId)

                try await LibraryFileManager.shared.renameTrack(
                    id: command.trackId,
                    to: command.targetFileName,
                    using: playerManager
                )

                succeeded.append(
                    BatchFilenameRenameSuccess(
                        trackId: command.trackId,
                        oldFileName: command.currentFileName,
                        newFileName: command.targetFileName
                    )
                )

                successfulUpdates.append(
                    TrackUpdateRequest(
                        trackId: command.trackId,
                        previousURL: previousURL
                    )
                )
            } catch {
                failed.append(
                    BatchFilenameRenameFailure(
                        trackId: command.trackId,
                        targetFileName: command.targetFileName,
                        error: error
                    )
                )
            }

            processedCount += 1
            if let progress {
                await progress(processedCount, totalCount)
            }
        }

        // Post-update pipeline может отклонить уже переименованный файл, если его metadata не удалось сохранить.
        // Файл не откатываем: отмечаем конкретный элемент ошибкой и публикуем batch-событие только для подтверждённых треков.
        var pendingUpdates = successfulUpdates
        let commandsByTrackId = Dictionary(
            uniqueKeysWithValues: commands.map { ($0.trackId, $0) }
        )

        while pendingUpdates.isEmpty == false {
            do {
                _ = try await TrackUpdateCoordinator.shared.handleTrackUpdates(pendingUpdates)
                break
            } catch let error as TrackUpdateCoordinatorError {
                let failedTrackId: UUID
                let underlyingError: Error

                switch error {
                case let .updateFailed(trackId, underlying):
                    failedTrackId = trackId
                    underlyingError = underlying
                }

                guard let failedIndex = pendingUpdates.firstIndex(where: { $0.trackId == failedTrackId }),
                      let command = commandsByTrackId[failedTrackId] else {
                    PersistentLogger.log("❌ batch rename: не удалось сопоставить ошибку post-update с треком \(failedTrackId)")
                    break
                }

                pendingUpdates.remove(at: failedIndex)
                succeeded.removeAll { $0.trackId == failedTrackId }
                failed.append(
                    BatchFilenameRenameFailure(
                        trackId: failedTrackId,
                        targetFileName: command.targetFileName,
                        error: underlyingError
                    )
                )
                PersistentLogger.log("❌ batch rename post-update failed trackId=\(failedTrackId) file already renamed: \(underlyingError)")

                // Повторяем подготовку оставшихся элементов: координатор публикует один batch только после полного успешного прохода.
            } catch {
                // Все ошибки подготовки оборачиваются координатором вместе с trackId, поэтому этот путь диагностический.
                PersistentLogger.log("❌ batch rename: unexpected post-update error \(error)")
                break
            }
        }

        return BatchFilenameRenameResult(
            succeeded: succeeded,
            failed: failed
        )
    }
    
    
    // MARK: - Добавить в треклист
    
    func addTrackToTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws {
        
        /// 1. Резолвим URL трека через bookmark
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            throw AppError.bookmarkResolveFailed
        }
        
        /// 2. Формируем модель Track для треклиста
        let source = await TrackRegistry.shared.entry(for: trackId)?.source ?? .library
        let imported = Track(
            trackId: trackId,
            title: nil,
            artist: nil,
            duration: 0,
            fileName: url.lastPathComponent,
            isAvailable: true,
            source: source
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

    /// Добавляет несколько треков в треклист одним сохранением.
    /// Используется как общий fallback для batch-flow, где нет LibraryTrack-моделей.
    func addTracksToTrackList(
        trackIds: [UUID],
        trackListId: UUID
    ) async throws {
        guard !trackIds.isEmpty else { return }

        var importedTracks: [Track] = []

        for trackId in trackIds {
            /// 1. Резолвим URL трека через bookmark.
            guard let url = await BookmarkResolver.url(forTrack: trackId) else {
                throw AppError.bookmarkResolveFailed
            }

            /// 2. Используем runtime snapshot, чтобы сохранить актуальные display-данные.
            let snapshot = await resolveSnapshot(for: trackId)
            let source = await TrackRegistry.shared.entry(for: trackId)?.source ?? .library
            let imported = Track(
                trackId: trackId,
                title: snapshot?.title,
                artist: snapshot?.artist,
                duration: snapshot?.duration ?? 0,
                fileName: snapshot?.fileName ?? url.lastPathComponent,
                isAvailable: true,
                source: source
            )
            importedTracks.append(imported)
        }

        /// 3. Сохраняем треклист одним append.
        let list = try TrackListManager.shared.addTracks(
            importedTracks,
            to: trackListId
        )
        let addedCount = importedTracks.count

        /// 4. Показываем один итоговый toast для batch-сценария.
        await MainActor.run {
            ToastManager.shared.handle(
                .tracksAddedToTrackList(
                    count: addedCount,
                    name: list.name
                )
            )
        }
    }

    /// Добавляет iTunes-треки в треклист без копирования и без BookmarkResolver.
    func addPurchasedITunesTracksToTrackList(
        _ tracks: [PurchasedITunesPlayableTrack],
        trackListId: UUID
    ) async throws {
        guard !tracks.isEmpty else { return }

        let importedTracks = tracks.map {
            Track(purchasedITunesTrack: $0)
        }

        let list = try TrackListManager.shared.addTracks(
            importedTracks,
            to: trackListId
        )

        let event: ToastEvent
        if tracks.count == 1, let track = tracks.first {
            event = trackAddedToTrackListEvent(
                for: track,
                trackListName: list.name
            )
        } else {
            event = .tracksAddedToTrackList(
                count: tracks.count,
                name: list.name
            )
        }

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
        
        let tracks: [Track] = playerTracks.map { $0.asTrack() }
        
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
        listItemId: UUID,
        trackListId: UUID
    ) async throws {
        
        /// 1. Получаем треклист
        var list = try TrackListManager.shared.getTrackListById(trackListId)
        
        /// 2. Находим конкретное вхождение трека в треклисте
        guard let index = list.tracks.firstIndex(where: { $0.id == listItemId }) else {
            throw AppError.trackNotFound
        }
        
        let removedTrack = list.tracks[index]
        
        /// 3. Удаляем только одно конкретное вхождение
        list.tracks.remove(at: index)
        
        /// 4. Сохраняем только после фактического удаления
        guard TrackListManager.shared.saveTracks(list.tracks, for: list.id) else {
            throw TrackListStorageError.saveFailed(trackListId: list.id)
        }
        
        /// 5. ToastEvent для iTunes строится из самой модели, без BookmarkResolver и snapshot-builder.
        let event: ToastEvent
        if removedTrack.isPurchasedITunesRuntimeTrack {
            event = trackRemovedFromTrackListEvent(for: removedTrack)
        } else {
            let trackId = removedTrack.trackId
            let snapshot = await resolveSnapshot(for: trackId)

            event = ToastEvent.trackRemovedFromTrackList(
                title: snapshot?.title ?? removedTrack.fileName,
                artist: snapshot?.artist ?? "",
                artwork: snapshot.flatMap {
                    ArtworkProvider.shared.image(
                        trackId: trackId,
                        artworkData: $0.artworkData,
                        purpose: .toast
                    ).map { Image(uiImage: $0) }
                }
            )
        }
        
        /// 6. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    // MARK: - Добавить в плеер
    
    func addTrackToPlayer(trackId: UUID) async throws {
        /// 1. Формируем runtime-модель очереди из актуального snapshot.
        let importItem = try await makePlayerTrackImportItem(trackId: trackId)

        /// 2. Мутация плеера — строго на MainActor.
        let didSave = await MainActor.run {
            PlaylistManager.shared.addTracks([importItem.track])
        }
        guard didSave else {
            throw AppError.playlistSaveFailed
        }

        /// 3. ToastEvent.
        let event = trackAddedToPlayerEvent(for: importItem)
        
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }

    /// Добавляет iTunes-трек в плеер через общий PlaylistManager без копирования файла.
    func addPurchasedITunesTrackToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) async throws {
        let playerTrack = PlayerTrack.make(from: track)

        let didSave = await MainActor.run {
            PlaylistManager.shared.addTracks([playerTrack])
        }
        guard didSave else {
            throw AppError.playlistSaveFailed
        }

        let event = trackAddedToPlayerEvent(for: track)

        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }

    /// Добавляет несколько треков в плеер одним сохранением очереди.
    func addTracksToPlayer(trackIds: [UUID]) async throws {
        guard !trackIds.isEmpty else { return }

        var importItems: [PlayerTrackImportItem] = []

        for trackId in trackIds {
            importItems.append(
                try await makePlayerTrackImportItem(trackId: trackId)
            )
        }

        let playerTracks = importItems.map { $0.track }
        let didSave = await MainActor.run {
            PlaylistManager.shared.addTracks(
                playerTracks
            )
        }

        guard didSave else {
            throw AppError.playlistSaveFailed
        }

        let event: ToastEvent
        if importItems.count == 1, let item = importItems.first {
            event = trackAddedToPlayerEvent(for: item)
        } else {
            event = .tracksAddedToPlayer(count: importItems.count)
        }

        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Удалить трек из плеера
    
    func removeTrackFromPlayer(queueItemId: UUID) async throws {
        
        // 1. Находим удаляемое вхождение и его trackId для тоста
        let removedTrack: PlayerTrack? = await MainActor.run {
            PlaylistManager.shared.tracks.first(where: { $0.id == queueItemId })
        }
        
        guard let removedTrack else {
            throw AppError.trackNotFound
        }
        
        // 2. Мутация плеера — строго MainActor
        let removeResult = await MainActor.run {
            let previousTracks = PlaylistManager.shared.tracks
            
            guard let index = PlaylistManager.shared.tracks.firstIndex(where: { $0.id == queueItemId }) else {
                return PlayerTrackRemovalResult.notFound
            }
            
            PlaylistManager.shared.tracks.remove(at: index)
            
            guard PlaylistManager.shared.saveQueue() else {
                PlaylistManager.shared.tracks = previousTracks
                return PlayerTrackRemovalResult.saveFailed
            }
            
            return PlayerTrackRemovalResult.removed
        }
        
        switch removeResult {
        case .removed:
            break
        case .notFound:
            throw AppError.trackNotFound
        case .saveFailed:
            throw AppError.playlistSaveFailed
        }
        
        // 3. ToastEvent для iTunes строится из самой модели, без BookmarkResolver и snapshot-builder.
        let event: ToastEvent
        if removedTrack.isPurchasedITunesRuntimeTrack {
            event = trackRemovedFromPlayerEvent(for: removedTrack)
        } else {
            let trackId = removedTrack.trackId
            let snapshot = await resolveSnapshot(for: trackId)

            event = ToastEvent.trackRemovedFromPlayer(
                title: snapshot?.title ?? snapshot?.fileName ?? removedTrack.fileName,
                artist: snapshot?.artist ?? "",
                artwork: snapshot.flatMap {
                    ArtworkProvider.shared.image(
                        trackId: trackId,
                        artworkData: $0.artworkData,
                        purpose: .toast
                    ).map { Image(uiImage: $0) }
                }
            )
        }
        
        // 4. Показ тоста
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Очистить плеер
    
    func clearPlayer() async {
        
        // 1. Очистка — строго MainActor
        let didClear = await MainActor.run {
            let previousTracks = PlaylistManager.shared.tracks
            PlaylistManager.shared.tracks.removeAll()
            guard PlaylistManager.shared.saveQueue() else {
                PlaylistManager.shared.tracks = previousTracks
                return false
            }
            return true
        }
        guard didClear else {
            await MainActor.run {
                ToastManager.shared.handle(.playlistSaveFailed)
            }
            return
        }
        
        // 2. ToastEvent
        await MainActor.run {
            ToastManager.shared.handle(.playerCleared)
        }
    }
    
    
    // MARK: - Сохранить изменения трека
    
    func saveTrackEdits(
        trackId: UUID,
        newFileName: String,
        fileChanged: Bool,
        patch: TagWritePatch,
        tagsChanged: Bool,
        artworkAction: ArtworkWriteAction,
        artworkChanged: Bool,
        using playerManager: PlayerManager
    ) async throws {
        // 1. Запоминаем старый URL до возможного переименования.
        // Это нужно, чтобы post-update pipeline мог сбросить кэши по старому пути.
        let previousURL = await BookmarkResolver.url(forTrack: trackId)
        // 2. Переименовываем файл без промежуточного success-toast.
        if fileChanged {
            do {
                try await LibraryFileManager.shared.renameTrack(
                    id: trackId,
                    to: newFileName,
                    using: playerManager
                )
            } catch let libraryError as LibraryFileError {
                throw appError(from: libraryError, fallback: .fileRenameFailed)
            }
        }
        // 3. Записываем теги и обложку без промежуточного success-toast.
        if tagsChanged || artworkChanged {
            guard let url = await BookmarkResolver.url(forTrack: trackId) else {
                throw TagWriteError.fileNotFound
            }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
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
            try await tagsWriter.writeTags(to: url, patch: finalPatch)
        }
        // 4. Собираем список реально изменённых полей для единого post-update pipeline.
        var changedFields: Set<TrackChangedField> = []
        if fileChanged {
            changedFields.insert(.fileName)
        }
        if tagsChanged || artworkChanged {
            changedFields.formUnion(
                changedFieldsForTagUpdate(
                    patch: patch,
                    artworkAction: artworkAction
                )
            )
        }
        // 5. Выбираем причину обновления для единого события.
        let updateReason: TrackUpdateReason
        if artworkChanged {
            updateReason = .artworkUpdated
        } else if tagsChanged {
            updateReason = .metadataUpdated
        } else {
            updateReason = .fileRenamed
        }
        // 6. Запускаем единый post-update pipeline после всех успешных операций.
        // Ошибка сохранения metadata намеренно доходит до action handler, который показывает существующий error-toast.
        let updateEvent = try await TrackUpdateCoordinator.shared.handleTrackUpdate(
            forTrackId: trackId,
            reason: updateReason,
            changedFields: changedFields,
            previousURL: previousURL
        )
        let snapshot = updateEvent?.snapshot
        // 7. Показываем только один итоговый success-toast.
        let event: ToastEvent
        if tagsChanged || artworkChanged {
            event = ToastEvent.tagsUpdated(
                title: snapshot?.title ?? snapshot?.fileName ?? newFileName,
                artist: snapshot?.artist ?? "",
                artwork: snapshot.flatMap {
                    ArtworkProvider.shared.image(
                        trackId: trackId,
                        artworkData: $0.artworkData,
                        purpose: .toast
                    ).map { Image(uiImage: $0) }
                }
            )
        } else {
            event = ToastEvent.fileRenamed(
                newName: snapshot?.fileName ?? newFileName
            )
        }
        await MainActor.run {
            ToastManager.shared.handle(event)
        }
    }
    
    
    // MARK: - Обновить теги трека
    
    func updateTrackTags(
        trackId: UUID,
        patch: TagWritePatch,
        artworkAction: ArtworkWriteAction,
        showsSuccessToast: Bool = true
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

        // Ошибка сохранения metadata не превращается в success-toast и обрабатывается вызывающим action handler.
        let updateEvent = try await TrackUpdateCoordinator.shared.handleTrackUpdate(
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
        if showsSuccessToast {
            await MainActor.run {
                ToastManager.shared.handle(event)
            }
        }
    }
}

// MARK: - Helper's

/// Результат удаления трека из очереди плеера.
/// Нужен, чтобы отличать фактическое удаление от ошибки сохранения.
private enum PlayerTrackRemovalResult {
    case removed
    case notFound
    case saveFailed
}

/// Подготовленный элемент импорта в очередь плеера.
/// Хранит и runtime-модель очереди, и snapshot для итогового toast.
private struct PlayerTrackImportItem {
    let track: PlayerTrack
    let snapshot: TrackRuntimeSnapshot?
}

/// Собирает runtime-модель плеера для одного trackId.
private func makePlayerTrackImportItem(trackId: UUID) async throws -> PlayerTrackImportItem {
    guard let url = await BookmarkResolver.url(forTrack: trackId) else {
        throw AppError.bookmarkResolveFailed
    }

    let snapshot = await resolveSnapshot(for: trackId)
    let source = await TrackRegistry.shared.entry(for: trackId)?.source ?? .library
    let track = PlayerTrack(
        trackId: trackId,
        title: snapshot?.title,
        artist: snapshot?.artist,
        duration: snapshot?.duration ?? 0,
        fileName: snapshot?.fileName ?? url.lastPathComponent,
        isAvailable: true,
        source: source
    )

    return PlayerTrackImportItem(
        track: track,
        snapshot: snapshot
    )
}

/// Строит одиночный toast добавления в плеер по подготовленному элементу.
private func trackAddedToPlayerEvent(for item: PlayerTrackImportItem) -> ToastEvent {
    let snapshot = item.snapshot

    return ToastEvent.trackAddedToPlayer(
        title: snapshot?.title ?? item.track.fileName,
        artist: snapshot?.artist ?? "",
        artwork: snapshot.flatMap {
            ArtworkProvider.shared.image(
                trackId: item.track.trackId,
                artworkData: $0.artworkData,
                purpose: .toast
            ).map { Image(uiImage: $0) }
        }
    )
}

/// Строит toast добавления iTunes-трека в плеер из runtime-данных MediaPlayer.
private func trackAddedToPlayerEvent(
    for track: PurchasedITunesPlayableTrack
) -> ToastEvent {
    ToastEvent.trackAddedToPlayer(
        title: track.title ?? track.fileName,
        artist: track.artist ?? "",
        artwork: toastArtwork(for: track)
    )
}

/// Строит toast добавления iTunes-трека в треклист из runtime-данных MediaPlayer.
private func trackAddedToTrackListEvent(
    for track: PurchasedITunesPlayableTrack,
    trackListName: String
) -> ToastEvent {
    ToastEvent.trackAddedToTrackList(
        title: track.title ?? track.fileName,
        artist: track.artist ?? "",
        artwork: toastArtwork(for: track),
        trackListName: trackListName
    )
}

/// Строит toast успешного копирования iTunes-трека из runtime-данных MediaPlayer.
private func trackCopiedFromITunesEvent(
    for track: PurchasedITunesPlayableTrack,
    folderName: String?
) -> ToastEvent {
    ToastEvent.trackCopiedFromITunes(
        title: track.title ?? track.fileName,
        artist: track.artist ?? "",
        artwork: toastArtwork(for: track),
        folderName: folderName
    )
}

/// Строит toast удаления iTunes-трека из плеера из сохранённых runtime-данных модели.
private func trackRemovedFromPlayerEvent(
    for track: PlayerTrack
) -> ToastEvent {
    ToastEvent.trackRemovedFromPlayer(
        title: track.title ?? track.fileName,
        artist: track.artist ?? "",
        artwork: toastArtwork(for: track)
    )
}

/// Строит toast удаления iTunes-трека из треклиста из сохранённых runtime-данных модели.
private func trackRemovedFromTrackListEvent(
    for track: Track
) -> ToastEvent {
    ToastEvent.trackRemovedFromTrackList(
        title: track.title ?? track.fileName,
        artist: track.artist ?? "",
        artwork: toastArtwork(for: track)
    )
}

/// Готовит обложку iTunes-трека для toast без файлового metadata cache.
private func toastArtwork(
    for track: any TrackDisplayable & PurchasedITunesTrackRepresentable
) -> Image? {
    ArtworkProvider.shared.image(
        trackId: track.trackId,
        artworkData: track.artworkData,
        purpose: .toast
    ).map { Image(uiImage: $0) }
}

/// Преобразует файловую ошибку фонотеки в ошибку пользовательского уровня.
///
/// LibraryFileManager остаётся низкоуровневым файловым слоем.
/// AppCommandExecutor переводит техническую причину в AppError,
/// который дальше маппится в ToastEvent.
private func appError(from error: LibraryFileError, fallback: AppError) -> AppError {
    switch error {
    case .trackIsPlaying:
        return .fileAccessDenied
    case .trackNotFound:
        return .trackNotFound
    case .sourceURLUnavailable:
        return .bookmarkResolveFailed
    case .destinationFolderUnavailable:
        return .libraryFolderUnavailable
    case .destinationAlreadyExists:
        return .fileAlreadyExists
    case .moveFailed:
        return fallback
    case .bookmarkCreationFailed:
        return .bookmarkCreateFailed
    case .relativePathFailed:
        return fallback
    }
}

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
    if let snapshot = await TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
        return snapshot
    }
    
    // 2. Fallback: собираем snapshot напрямую
    return try? await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
}
