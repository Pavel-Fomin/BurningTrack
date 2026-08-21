//
//  LibrarySyncModule.swift
//  TrackList
//
//  Sync-модуль фонотеки.
//  Единственная ответственность:
//  — привести реестры (TrackRegistry + BookmarksRegistry) в соответствие фактическому
//    состоянию файловой системы фонотеки.
//
//  Жёсткие границы:
//  — не знает про UI
//  — не читает метаданные аудио (теги/обложки/длительность)
//  — trackId создаётся только через TrackIdentityResolver
//  — источник фактов о ФС: LibraryScanner
//
//  Created by Pavel Fomin on 30.12.2025.
//

import Foundation

/// Координирует логические синхронизации отдельно для каждого корня фонотеки.
///
/// `LibrarySyncModule` остаётся reentrant во время сканирования и операций с реестрами,
/// поэтому очередь живёт в отдельном actor. Запрос одного `rootFolderId` начинает scan
/// только после полного завершения предыдущего; независимые корни не блокируют друг друга.
actor LibraryRootSyncCoordinator {

    private struct WaitingRequest {
        let id: UUID
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct RootState {
        var activeRequestID: UUID
        var waitingRequests: [WaitingRequest]
    }

    private var states: [UUID: RootState] = [:]

    /// Выполняет operation в очереди её root-папки.
    ///
    /// Если ожидающий вызывающий код отменён, continuation намеренно дожидается своей очереди:
    /// сразу после получения ownership проверяется cancellation, запрос не входит в
    /// operation и освобождает место следующему. Так не нужен отдельный небезопасный
    /// механизм удаления continuation из очереди.
    func run(
        rootFolderId: UUID,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        let requestID = UUID()
        await acquire(rootFolderId: rootFolderId, requestID: requestID)

        do {
            try Task.checkCancellation()
            try await operation()
            release(rootFolderId: rootFolderId, requestID: requestID)
        } catch {
            // Ошибка или отмена одной операции не должны удерживать root и блокировать
            // независимый следующий запрос этой же папки.
            release(rootFolderId: rootFolderId, requestID: requestID)
            throw error
        }
    }

    private func acquire(rootFolderId: UUID, requestID: UUID) async {
        guard states[rootFolderId] != nil else {
            states[rootFolderId] = RootState(
                activeRequestID: requestID,
                waitingRequests: []
            )
            return
        }

        await withCheckedContinuation { continuation in
            states[rootFolderId]?.waitingRequests.append(
                WaitingRequest(id: requestID, continuation: continuation)
            )
        }
    }

    private func release(rootFolderId: UUID, requestID: UUID) {
        guard var state = states[rootFolderId], state.activeRequestID == requestID else {
            return
        }

        guard state.waitingRequests.isEmpty == false else {
            states[rootFolderId] = nil
            return
        }

        let nextRequest = state.waitingRequests.removeFirst()
        state.activeRequestID = nextRequest.id
        states[rootFolderId] = state
        nextRequest.continuation.resume()
    }
}

/// Содержит чистые правила reconciliation, используемые sync-body.
/// Выделение правил сохраняет проверяемыми границы `.safe`, `.full` и empty-scan,
/// не меняя ownership TrackRegistry и BookmarksRegistry.
enum LibrarySyncReconciliation {

    static func shouldApply(scannedFileCount: Int) -> Bool {
        scannedFileCount > 0
    }

    static func entriesToDelete(
        existing: [TrackRegistry.TrackEntry],
        aliveIDs: Set<UUID>,
        mode: LibrarySyncModule.SyncMode
    ) -> [TrackRegistry.TrackEntry] {
        guard case .full = mode else {
            return []
        }

        return existing.filter { aliveIDs.contains($0.id) == false }
    }
}

actor LibrarySyncModule {
    
    enum SyncMode {
        case safe
        case full
    }

    static let shared = LibrarySyncModule()

    private let scanner = LibraryScanner()
    private let rootSyncCoordinator = LibraryRootSyncCoordinator()

    private init() {}

    // MARK: - Публичный API

    /// Синхронизирует один корневой раздел фонотеки:
    /// - сканирует все аудиофайлы внутри rootURL
    /// - для каждого файла получает постоянный trackId через TrackIdentityResolver
    /// - обновляет TrackRegistry/BookmarksRegistry
    /// - удаляет из реестров треки, которых больше нет в файловой системе
    ///
    /// Важно: URL может меняться, идентичность файла — нет.
    /// 
    func syncRootFolder(
        rootFolderId: UUID,
        rootURL: URL,
        mode: SyncMode,
        logsDatabaseDiagnostics: Bool = true
    ) async throws {

        try await rootSyncCoordinator.run(rootFolderId: rootFolderId) {
            try await self.performSyncRootFolder(
                rootFolderId: rootFolderId,
                rootURL: rootURL,
                mode: mode,
                logsDatabaseDiagnostics: logsDatabaseDiagnostics
            )
        }
    }

    /// Выполняет существующую бизнес-логику одной root-operation после получения ownership.
    /// Пока этот метод не завершится, следующий sync того же root не может начать scan и
    /// поэтому не применит snapshot файловой системы, устаревший ещё во время ожидания.
    private func performSyncRootFolder(
        rootFolderId: UUID,
        rootURL: URL,
        mode: SyncMode,
        logsDatabaseDiagnostics: Bool
    ) async throws {

        // Отмена между передачей ownership и первой проверкой доступа не должна
        // открывать scope и запускать scan для уже неактуального запроса.
        try Task.checkCancellation()
        
        /// Защита от разрушительного sync во время boot процесса.
        /// Если библиотека ещё не перешла в состояние ready,
        /// синхронизацию запускать нельзя.
        let accessState = await MainActor.run {
            MusicLibraryManager.shared.accessState
        }
        try Task.checkCancellation()

        if accessState != .ready {
            PersistentLogger.log("⚠️ sync blocked: library not ready")
            print("⚠️ syncRootFolder: пропуск — библиотека ещё не ready")
            return
        }

        // 1) Открываем доступ к корневой папке на время синка.
        // Если MusicLibraryManager уже держит root-доступ, повторный start может вернуть false.
        // В этом случае продолжаем синк и не закрываем runtime-доступ менеджера.
        let hasRuntimeRootAccess = await MainActor.run {
            MusicLibraryManager.shared.hasActiveRootAccess(
                rootFolderId: rootFolderId,
                url: rootURL
            )
        }
        let started = rootURL.startAccessingSecurityScopedResource()
        if !started && hasRuntimeRootAccess == false {
            print("❌ syncRootFolder: не удалось начать доступ к папке:", rootURL.path)
            return
        }
        defer {
            if started {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        // 2) Сканируем все аудиофайлы рекурсивно
        let scanned = await scanner.scanRecursively(rootURL)
        // Отмена после scan не начинает registry-mutations. После первой mutation
        // cancellation специально не проверяется, потому что rollback ещё не существует.
        try Task.checkCancellation()

        if LibrarySyncReconciliation.shouldApply(scannedFileCount: scanned.count) == false {
            print("⚠️ syncRootFolder: scan вернул 0 файлов — пропускаем удаление, чтобы не снести реестр:", rootURL.lastPathComponent)
            PersistentLogger.log("⚠️ syncRootFolder: empty scan root=\(rootURL.lastPathComponent) mode=\(mode)")
            return
        }

        // 3) Получаем текущее состояние реестра по корню
        let existing = await TrackRegistry.shared.tracks(inRootFolder: rootFolderId)
        // Если отмена пришла до первой mutation, root освобождается без частичного sync.
        try Task.checkCancellation()

        var existingByRelativePath: [String: TrackRegistry.TrackEntry] = [:]
        for entry in existing {
            guard let relativePath = entry.relativePath else { continue }
            existingByRelativePath[relativePath] = entry
        }

        // 4) Применяем найденные файлы: upsert + bookmark
        var aliveIds = Set<UUID>()
        for file in scanned {

            let fileURL = file.url.resolvingSymlinksInPath()
            let fileName = file.fileName
            let folderId = file.folderURL.resolvingSymlinksInPath().libraryFolderId
            let fileValues = try? fileURL.resourceValues(
                forKeys: [
                    .contentModificationDateKey,
                    .creationDateKey
                ]
            )
            let fileDate =
                fileValues?.contentModificationDate ??
                fileValues?.creationDate ??
                Date()
            // Размер берётся только из файлового атрибута и не требует чтения аудиоданных.
            let fileSize = LibraryFileSizeResolver.fileSize(for: fileURL)
            
            let rootPath = rootURL.standardizedFileURL.path.hasSuffix("/")
                ? rootURL.standardizedFileURL.path
                : rootURL.standardizedFileURL.path + "/"

            let filePath = fileURL.standardizedFileURL.path

            guard filePath.hasPrefix(rootPath) else {
                print("⚠️ syncRootFolder: файл вне root:", fileURL.path)
                continue
            }

            let relativePath = String(filePath.dropFirst(rootPath.count))

            // Для фонотеки identity строится не из байтов файла,
            // а из logical path внутри root-папки.
            // Если запись уже была в реестре, сохраняем её старый trackId.
            let existingEntry = existingByRelativePath[relativePath]

            let trackId = try await TrackIdentityResolver.shared.trackId(
                forRootFolderId: rootFolderId,
                relativePath: relativePath,
                preferredExistingId: existingEntry?.id
            )

            aliveIds.insert(trackId)

            await TrackRegistry.shared.upsertTrack(
                id: trackId,
                fileName: fileName,
                relativePath: relativePath,
                folderId: folderId,
                rootFolderId: rootFolderId,
                fileDate: fileDate,
                fileSize: fileSize,
                shouldUpdateFileSize: true
            )

            // Bookmark файла (может обновляться, это не идентичность)
            if let base64 = BookmarkResolver.makeBookmarkBase64(for: fileURL) {
                await BookmarksRegistry.shared.upsertTrackBookmark(id: trackId, base64: base64)
            } else {
                print("⚠️ syncRootFolder: не удалось создать bookmark файла:", fileURL.path)
            }
        }

        // 5) Удаляем только в full-режиме
        for entry in LibrarySyncReconciliation.entriesToDelete(
            existing: existing,
            aliveIDs: aliveIds,
            mode: mode
        ) {
            await TrackRegistry.shared.removeTrack(id: entry.id)
            await BookmarksRegistry.shared.removeTrackBookmark(id: entry.id)

            // Трек реально исчез из библиотеки.
            // Значит его library identity тоже нужно забыть.
            if let rootFolderId = entry.rootFolderId,
               let relativePath = entry.relativePath {
                try await TrackIdentityResolver.shared.unbindLibraryTrack(
                    rootFolderId: rootFolderId,
                    relativePath: relativePath
                )
            }

            // И дополнительно очищаем все привязки к этому trackId,
            // чтобы потом другой файл по старому пути не воскресил старый id.
            try await TrackIdentityResolver.shared.forgetTrack(id: entry.id)
        }
        // 6) Финальная проверка ошибок выполняется только после валидной синхронизации.
        // До этого места код доходит только если:
        // - библиотека находится в состоянии ready
        // - доступ к rootURL успешно открыт
        // - scanner вернул надёжный непустой результат
        // Если запись в SQLite не прошла, sync не должен считаться успешным.
        try await TrackRegistry.shared.throwPendingPersistenceError()
        try await BookmarksRegistry.shared.throwPendingPersistenceError()

        // Сигнал отправляется только после завершения всех записей реестров,
        // чтобы корневые счётчики не начинали чтение промежуточного состояния.
        await MainActor.run {
            NotificationCenter.default.post(name: .libraryDataDidChange, object: nil)
        }
        
        // Лог завершения sync не содержит счётчик удалений, потому что фактическое состояние БД логируется отдельно.
        print("✅ syncRootFolder завершён:", rootURL.lastPathComponent, "режим:", mode, "файлов:", scanned.count)

        #if DEBUG
        // DEBUG-снимок показывает состояние SQLite после финальной проверки, а не статистику текущей операции.
        if logsDatabaseDiagnostics {
            DatabaseDiagnosticsLogger.logLibrarySnapshot()
        }
        #endif
    }
}
