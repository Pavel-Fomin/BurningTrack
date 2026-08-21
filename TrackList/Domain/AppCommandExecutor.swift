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
/// MainActor является границей пользовательских намерений, а длительная файловая работа
/// остаётся у её actor-owner-ов. Это не заменяет per-track ownership coordinator-а.
@MainActor
final class AppCommandExecutor {
    
    // MARK: - Зависимости
    
    /// Явный owner сериализует полный файловый сценарий конкретного трека.
    private let trackFileOperationCoordinator: TrackFileOperationCoordinator
    /// Выполняет физическую мутацию файла и обновляет file-level registry state.
    private let trackFileManager: any TrackFileOperationManaging
    /// Читает bookmark только после получения ownership конкретного трека.
    private let trackFileURLResolver: any TrackFileURLResolving
    /// Выполняет post-update и его batch-публикацию без второго lock owner-а.
    private let trackPostUpdateHandler: any TrackPostUpdateHandling
    /// Разрешает display name папки внутри защищённого move-сценария.
    private let trackFolderNameResolver: any TrackFolderNameResolving
    /// Пишет теги только внутри ownership того же физического файла.
    private let tagsWriter: any TagsWriter

    static let shared = AppCommandExecutor()

    /// Собирает минимальные зависимости file-operation boundary.
    ///
    /// Production продолжает использовать существующий shared executor, а узкие
    /// capability позволяют контролируемо проверить ownership без файловой системы и SQLite.
    init(
        trackFileOperationCoordinator: TrackFileOperationCoordinator = TrackFileOperationCoordinator(),
        trackFileManager: any TrackFileOperationManaging = LibraryFileManager.shared,
        trackFileURLResolver: any TrackFileURLResolving = BookmarkTrackFileURLResolver(),
        trackPostUpdateHandler: any TrackPostUpdateHandling = TrackUpdateCoordinator.shared,
        trackFolderNameResolver: any TrackFolderNameResolving = TrackRegistryFolderNameResolver(),
        tagsWriter: any TagsWriter = TagLibTagsWriter()
    ) {
        self.trackFileOperationCoordinator = trackFileOperationCoordinator
        self.trackFileManager = trackFileManager
        self.trackFileURLResolver = trackFileURLResolver
        self.trackPostUpdateHandler = trackPostUpdateHandler
        self.trackFolderNameResolver = trackFolderNameResolver
        self.tagsWriter = tagsWriter
    }
    
    // MARK: - Переместить трек
    
    func moveTrack(
        trackId: UUID,
        toFolder folderId: UUID,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> MoveTrackSuccess {
        try await trackFileOperationCoordinator.run(trackId: trackId) {
            // Bookmark читается только после получения ownership, иначе он мог бы устареть в очереди.
            let previousURL = await self.trackFileURLResolver.url(forTrackId: trackId)

            do {
                try await self.trackFileManager.moveTrack(
                    id: trackId,
                    toFolder: folderId,
                    using: fileBusyChecker
                )
            } catch let libraryError as LibraryFileError {
                throw appError(from: libraryError, fallback: .fileMoveFailed)
            }

            // Владение удерживается до конца post-update, чтобы другой command не увидел промежуточный path.
            let updateEvent = try await self.trackPostUpdateHandler.handleTrackUpdate(
                forTrackId: trackId,
                reason: .fileMoved,
                changedFields: [.fileName],
                previousURL: previousURL
            )

            let folderName = await self.trackFolderNameResolver.folderName(forFolderId: folderId)
            return MoveTrackSuccess(
                trackId: trackId,
                destinationFolderId: folderId,
                destinationFolderName: folderName,
                snapshot: updateEvent?.snapshot
            )
        }
    }

    // MARK: - Копировать iTunes-трек

    /// Принимает выбранную папку назначения для копирования iTunes-трека.
    /// Файловая операция выполняется через отдельный manager, без BookmarkResolver
    /// и файлового metadata cache для исходного iTunes-трека.
    func copyPurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack,
        toFolder folderId: UUID
    ) async throws -> CopyPurchasedITunesTrackSuccess {
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

            return CopyPurchasedITunesTrackSuccess(
                sourceTrackId: track.trackId,
                copiedFileURL: result.fileURL,
                destinationFolderId: result.folderId,
                destinationFolderName: result.folderName
            )
        } catch {
            print("❌ copyPurchasedITunesTrack failed:", error)
            throw AppError.purchasedITunesCopyFailed
        }
    }
    
    
    // MARK: -  Переименовать файл

    func renameTrack(
        trackId: UUID,
        to newFileName: String,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> RenameTrackSuccess {
        try await trackFileOperationCoordinator.run(trackId: trackId) {
            // Старый URL нужен post-update и должен отражать состояние после всех предыдущих команд этого трека.
            let previousURL = await self.trackFileURLResolver.url(forTrackId: trackId)

            do {
                try await self.trackFileManager.renameTrack(
                    id: trackId,
                    to: newFileName,
                    using: fileBusyChecker
                )
            } catch let libraryError as LibraryFileError {
                throw appError(from: libraryError, fallback: .fileRenameFailed)
            }

            let updateEvent = try await self.trackPostUpdateHandler.handleTrackUpdate(
                forTrackId: trackId,
                reason: .fileRenamed,
                changedFields: [.fileName],
                previousURL: previousURL
            )

            return RenameTrackSuccess(
                trackId: trackId,
                finalFileName: updateEvent?.snapshot.fileName ?? newFileName,
                snapshot: updateEvent?.snapshot
            )
        }
    }

    /// Массово переименовывает файлы треков.
    ///
    /// Batch удерживает ownership всех своих trackId до публикации общего post-update события.
    /// Это сохраняет batch-semantics и не открывает окно между rename отдельного файла и его post-update.
    func renameTrackFilesBatch(
        _ commands: [BatchFilenameRenameCommand],
        using fileBusyChecker: any TrackFileBusyChecking,
        progress: (@MainActor @Sendable (_ processed: Int, _ total: Int) -> Void)? = nil
    ) async -> BatchFilenameRenameResult {
        do {
            return try await trackFileOperationCoordinator.run(
                trackIds: commands.map(\.trackId)
            ) {
                var succeeded: [BatchFilenameRenameSuccess] = []
                var failed: [BatchFilenameRenameFailure] = []
                var updateEvents: [TrackUpdateEvent] = []
                var processedCount = 0
                let totalCount = commands.count

                for command in commands {
                    do {
                        // Batch получил ownership заранее, поэтому bookmark читается после завершения внешних команд этих треков.
                        let previousURL = await self.trackFileURLResolver.url(forTrackId: command.trackId)
                        try await self.trackFileManager.renameTrack(
                            id: command.trackId,
                            to: command.targetFileName,
                            using: fileBusyChecker
                        )

                        let updateEvent = try await self.trackPostUpdateHandler.prepareTrackUpdate(
                            forTrackId: command.trackId,
                            reason: .fileRenamed,
                            changedFields: [.fileName],
                            previousURL: previousURL
                        )
                        if let updateEvent {
                            updateEvents.append(updateEvent)
                        }
                        succeeded.append(
                            BatchFilenameRenameSuccess(
                                trackId: command.trackId,
                                oldFileName: command.currentFileName,
                                newFileName: command.targetFileName
                            )
                        )
                    } catch {
                        // Физически изменённый файл не откатываем; ошибка остаётся привязанной к конкретной строке batch.
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

                // Единое batch-событие публикуется до освобождения ownership всех успешных файлов.
                await self.trackPostUpdateHandler.publishTrackBatchUpdateEvents(updateEvents)
                return BatchFilenameRenameResult(succeeded: succeeded, failed: failed)
            }
        } catch {
            // Отменённый batch не выполняет ещё не получившее ownership тело и сообщает ошибку каждой не обработанной строке.
            return BatchFilenameRenameResult(
                succeeded: [],
                failed: commands.map {
                    BatchFilenameRenameFailure(
                        trackId: $0.trackId,
                        targetFileName: $0.targetFileName,
                        error: error
                    )
                }
            )
        }
    }
    
    
    // MARK: - Добавить в треклист
    
    func addTrackToTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws -> TrackAddedToTrackListSuccess {
        
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
        
        return TrackAddedToTrackListSuccess(
            addedTrack: imported,
            trackListId: list.id,
            trackListName: list.name
        )
    }

    /// Добавляет несколько треков в треклист одним сохранением.
    /// Используется как общий fallback для batch-flow, где нет LibraryTrack-моделей.
    func addTracksToTrackList(
        trackIds: [UUID],
        trackListId: UUID
    ) async throws -> TracksAddedToTrackListSuccess {
        guard !trackIds.isEmpty else {
            let list = try TrackListManager.shared.getTrackListById(trackListId)
            return TracksAddedToTrackListSuccess(
                addedTrackIds: [],
                trackListId: list.id,
                trackListName: list.name
            )
        }

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
        return TracksAddedToTrackListSuccess(
            addedTrackIds: importedTracks.map(\.trackId),
            trackListId: list.id,
            trackListName: list.name
        )
    }

    /// Добавляет iTunes-треки в треклист без копирования и без BookmarkResolver.
    func addPurchasedITunesTracksToTrackList(
        _ tracks: [PurchasedITunesPlayableTrack],
        trackListId: UUID
    ) async throws -> PurchasedITunesTracksAddedToTrackListSuccess {
        guard !tracks.isEmpty else {
            let list = try TrackListManager.shared.getTrackListById(trackListId)
            return PurchasedITunesTracksAddedToTrackListSuccess(
                addedTracks: [],
                trackListId: list.id,
                trackListName: list.name
            )
        }

        let importedTracks = tracks.map {
            Track(purchasedITunesTrack: $0)
        }

        let list = try TrackListManager.shared.addTracks(
            importedTracks,
            to: trackListId
        )

        return PurchasedITunesTracksAddedToTrackListSuccess(
            addedTracks: importedTracks,
            trackListId: list.id,
            trackListName: list.name
        )
    }
    
    // MARK: - Создать треклист
    
    func createTrackList(
        name: String
    ) async throws -> TrackListCreatedSuccess {
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrackListManager.shared.validateName(trimmed) else {
            throw AppError.trackListNameInvalid
        }
        
        // PlaylistManager — @MainActor → нужен await
        let playerTracks = PlaylistManager.shared.tracks
        
        let tracks: [Track] = playerTracks.map { $0.asTrack() }
        
        let created = try TrackListsManager.shared.createTrackList(
            from: tracks,
            withName: trimmed
        )
        
        return TrackListCreatedSuccess(
            trackListId: created.id,
            trackListName: created.name
        )
    }
    
    
    // MARK: - Переименовать треклист
    
    func renameTrackList(
        trackListId: UUID,
        newName: String
    ) async throws -> TrackListRenamedSuccess {
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Переименование
        try TrackListsManager.shared.renameTrackList(
            id: trackListId,
            to: trimmed
        )
        
        return TrackListRenamedSuccess(
            trackListId: trackListId,
            trackListName: trimmed
        )
    }
    
    // MARK: - Удалить трек из треклиста
    
    func removeTrackFromTrackList(
        listItemId: UUID,
        trackListId: UUID
    ) async throws -> TrackRemovedFromTrackListSuccess {
        
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
        
        return TrackRemovedFromTrackListSuccess(
            removedTrack: removedTrack,
            trackListId: list.id
        )
    }
    
    // MARK: - Добавить в плеер
    
    func addTrackToPlayer(trackId: UUID) async throws -> TrackAddedToPlayerSuccess {
        /// 1. Формируем runtime-модель очереди из актуального snapshot.
        let importItem = try await makePlayerTrackImportItem(trackId: trackId)

        /// 2. Мутация плеера — строго на MainActor.
        let didSave = await MainActor.run {
            PlaylistManager.shared.addTracks([importItem.track])
        }
        guard didSave else {
            throw AppError.playlistSaveFailed
        }

        return TrackAddedToPlayerSuccess(
            addedTrack: importItem.track,
            snapshot: importItem.snapshot
        )
    }

    /// Добавляет iTunes-трек в плеер через общий PlaylistManager без копирования файла.
    func addPurchasedITunesTrackToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) async throws -> PurchasedITunesTrackAddedToPlayerSuccess {
        let playerTrack = PlayerTrack.make(from: track)

        let didSave = await MainActor.run {
            PlaylistManager.shared.addTracks([playerTrack])
        }
        guard didSave else {
            throw AppError.playlistSaveFailed
        }

        return PurchasedITunesTrackAddedToPlayerSuccess(addedTrack: playerTrack)
    }

    /// Добавляет несколько треков в плеер одним сохранением очереди.
    func addTracksToPlayer(trackIds: [UUID]) async throws -> TracksAddedToPlayerSuccess {
        guard !trackIds.isEmpty else {
            return TracksAddedToPlayerSuccess(addedTracks: [])
        }

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

        return TracksAddedToPlayerSuccess(
            addedTracks: importItems.map {
                TrackAddedToPlayerSuccess(
                    addedTrack: $0.track,
                    snapshot: $0.snapshot
                )
            }
        )
    }
    
    
    // MARK: - Удалить трек из плеера
    
    func removeTrackFromPlayer(queueItemId: UUID) async throws -> TrackRemovedFromPlayerSuccess {
        
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
        
        return TrackRemovedFromPlayerSuccess(removedTrack: removedTrack)
    }
    
    
    // MARK: - Очистить плеер
    
    func clearPlayer() async throws -> PlayerClearedSuccess {
        
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
        guard didClear else { throw AppError.playlistSaveFailed }

        return PlayerClearedSuccess()
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
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackEditsSavedSuccess {
        try await trackFileOperationCoordinator.run(trackId: trackId) {
            // Старый bookmark читается после ownership и остаётся согласованным с rename внутри этой команды.
            let previousURL = await self.trackFileURLResolver.url(forTrackId: trackId)

            if fileChanged {
                do {
                    try await self.trackFileManager.renameTrack(
                        id: trackId,
                        to: newFileName,
                        using: fileBusyChecker
                    )
                } catch let libraryError as LibraryFileError {
                    throw appError(from: libraryError, fallback: .fileRenameFailed)
                }
            }

            // Tag writer меняет содержимое того же файла, поэтому не может пересечься с move или rename.
            if tagsChanged || artworkChanged {
                guard let url = await self.trackFileURLResolver.url(forTrackId: trackId) else {
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
                try await self.tagsWriter.writeTags(to: url, patch: finalPatch)
            }

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

            let updateReason: TrackUpdateReason
            if artworkChanged {
                updateReason = .artworkUpdated
            } else if tagsChanged {
                updateReason = .metadataUpdated
            } else {
                updateReason = .fileRenamed
            }

            // Ошибка metadata не скрывается, но ownership освобождается только после выхода из post-update.
            let updateEvent = try await self.trackPostUpdateHandler.handleTrackUpdate(
                forTrackId: trackId,
                reason: updateReason,
                changedFields: changedFields,
                previousURL: previousURL
            )
            let snapshot = updateEvent?.snapshot

            return TrackEditsSavedSuccess(
                trackId: trackId,
                finalFileName: snapshot?.fileName ?? newFileName,
                snapshot: snapshot,
                didUpdateTagsOrArtwork: tagsChanged || artworkChanged
            )
        }
    }


    // MARK: - Обновить теги трека

    func updateTrackTags(
        trackId: UUID,
        patch: TagWritePatch,
        artworkAction: ArtworkWriteAction
    ) async throws -> TrackTagsUpdatedSuccess {
        try await trackFileOperationCoordinator.run(trackId: trackId) {
            // URL mutable-файла резолвится под тем же ownership, что и subsequent tag write.
            guard let url = await self.trackFileURLResolver.url(forTrackId: trackId) else {
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

            try await self.tagsWriter.writeTags(to: url, patch: finalPatch)

            let changedFields = changedFieldsForTagUpdate(
                patch: finalPatch,
                artworkAction: artworkAction
            )
            let updateReason: TrackUpdateReason = artworkAction == .none
                ? .metadataUpdated
                : .artworkUpdated

            let updateEvent = try await self.trackPostUpdateHandler.handleTrackUpdate(
                forTrackId: trackId,
                reason: updateReason,
                changedFields: changedFields,
                previousURL: nil
            )

            return TrackTagsUpdatedSuccess(
                trackId: trackId,
                snapshot: updateEvent?.snapshot
            )
        }
    }
}

// MARK: - File operation capabilities

/// Выполняет мутации физического файла и связанных file-level реестров.
///
/// Per-track ownership остаётся в AppCommandExecutor: реализация capability
/// не создаёт второй competing lock owner вокруг отдельных вызовов FileManager.
protocol TrackFileOperationManaging: Sendable {
    func moveTrack(
        id trackId: UUID,
        toFolder destinationFolderId: UUID,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws

    func renameTrack(
        id trackId: UUID,
        to newFileName: String,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws
}

/// Резолвит URL существующего файла из bookmark после получения ownership.
protocol TrackFileURLResolving: Sendable {
    func url(forTrackId trackId: UUID) async -> URL?
}

/// Возвращает display name папки для сформированного move-result.
protocol TrackFolderNameResolving: Sendable {
    func folderName(forFolderId folderId: UUID) async -> String?
}

/// Выполняет post-update без владения очередью файловых операций.
protocol TrackPostUpdateHandling: Sendable {
    func handleTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent?

    func prepareTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent?

    func publishTrackBatchUpdateEvents(_ updateEvents: [TrackUpdateEvent]) async
}

/// Production-адаптер bookmark resolver без раскрытия global singleton в test seam.
struct BookmarkTrackFileURLResolver: TrackFileURLResolving {
    func url(forTrackId trackId: UUID) async -> URL? {
        await BookmarkResolver.url(forTrack: trackId)
    }
}

/// Production-адаптер получения имени destination folder для результата move-команды.
struct TrackRegistryFolderNameResolver: TrackFolderNameResolving {
    func folderName(forFolderId folderId: UUID) async -> String? {
        await TrackRegistry.shared
            .allFolders()
            .first(where: { $0.id == folderId })?
            .name
    }
}

extension LibraryFileManager: TrackFileOperationManaging {}

extension TrackUpdateCoordinator: TrackPostUpdateHandling {}

// MARK: - Helper's

/// Результат удаления трека из очереди плеера.
/// Нужен, чтобы отличать фактическое удаление от ошибки сохранения.
private enum PlayerTrackRemovalResult {
    case removed
    case notFound
    case saveFailed
}

/// Подготовленный элемент импорта в очередь плеера.
/// Хранит runtime-модель очереди и snapshot, использованный при её формировании.
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

/// Преобразует файловую ошибку фонотеки в ошибку пользовательского уровня.
///
/// LibraryFileManager остаётся низкоуровневым файловым слоем.
/// AppCommandExecutor переводит техническую причину в AppError,
/// который обрабатывается presentation-слоем.
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
