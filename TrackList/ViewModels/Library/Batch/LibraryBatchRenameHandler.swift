//
//  LibraryBatchRenameHandler.swift
//  TrackList
//
//  Обрабатывает массовое переименование файлов фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Combine
import Foundation

/// Ограничивает количество одновременно выполняемых задач.
/// Нужен для безопасной загрузки metadata большого количества файлов.
private actor LibraryBatchRenameAsyncLimiter {
    private let limit: Int
    private var running = 0

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        while running >= limit {
            await Task.yield()
        }

        running += 1
    }

    func release() {
        running -= 1
    }
}

/// Обрабатывает массовое переименование файлов фонотеки.
/// Не знает про selection и не управляет UI списка.
@MainActor
final class LibraryBatchRenameHandler: ObservableObject {

    // MARK: - State

    /// Flow массового переименования файлов.
    @Published private(set) var flow = BatchFilenameRenameFlow()

    // MARK: - Dependencies

    private let snapshotProvider: @MainActor (UUID) -> TrackRuntimeSnapshot?
    private let snapshotLoader: @MainActor (UUID) async -> TrackRuntimeSnapshot?
    private let tracksProvider: @MainActor () -> [LibraryTrack]
    private let commandExecutor: AppCommandExecutor
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        snapshotProvider: @escaping @MainActor (UUID) -> TrackRuntimeSnapshot?,
        snapshotLoader: @escaping @MainActor (UUID) async -> TrackRuntimeSnapshot?,
        tracksProvider: @escaping @MainActor () -> [LibraryTrack],
        commandExecutor: AppCommandExecutor = .shared
    ) {
        self.snapshotProvider = snapshotProvider
        self.snapshotLoader = snapshotLoader
        self.tracksProvider = tracksProvider
        self.commandExecutor = commandExecutor

        bindFlow()
    }

    // MARK: - Public

    /// Запускает flow массового переименования файлов.
    func startRename(with pendingAction: PendingBulkTrackAction) {
        startLoading(with: pendingAction)

        Task { @MainActor in
            await prepareRename(with: pendingAction)
        }
    }

    /// Применяет массовое переименование файлов для готовых строк плана.
    func applyRename(using playerManager: PlayerManager) async {
        guard !flow.isBusy else { return }
        // До выбора стратегии targetFileName равен текущему имени, поэтому применять такой план нельзя.
        guard flow.strategy != nil else { return }

        let commands = flow.items
            .filter { $0.status == .ready }
            .map { item in
                BatchFilenameRenameCommand(
                    trackId: item.trackId,
                    currentFileName: item.currentFileName,
                    targetFileName: item.targetFileName
                )
            }

        guard !commands.isEmpty else { return }

        flow.startApplyingRename(totalCount: commands.count)
        defer {
            flow.finishApplyingRename()
        }

        let result = await commandExecutor.renameTrackFilesBatch(
            commands,
            using: playerManager,
            progress: { [weak self] processed, _ in
                self?.flow.updateApplyingRenameProgress(
                    processedCount: processed
                )
            }
        )

        flow.applyResult(result)
    }

    // MARK: - Private

    /// Пробрасывает изменения flow наружу для подписчиков handler.
    private func bindFlow() {
        flow.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Сразу открывает sheet массового переименования,
    /// пока metadata выбранных файлов ещё загружается.
    private func startLoading(with pendingAction: PendingBulkTrackAction) {
        flow.startLoadingMetadata(
            with: pendingAction,
            tracks: filenameRenameTracks(for: pendingAction.trackIDs)
        )
        flow.startPreparingRename(
            totalCount: pendingAction.trackIDs.count
        )
    }

    /// Подготавливает flow массового переименования после загрузки runtime metadata.
    private func prepareRename(with pendingAction: PendingBulkTrackAction) async {
        defer {
            flow.finishPreparingRename()
        }

        await ensureSnapshots(trackIDs: pendingAction.trackIDs)

        guard flow.pendingAction?.action == .renameFiles else { return }

        let currentTrackIDs = flow.pendingAction?.trackIDs ?? []
        guard !currentTrackIDs.isEmpty else { return }

        flow.prepare(
            with: PendingBulkTrackAction(
                action: .renameFiles,
                trackIDs: currentTrackIDs
            ),
            tracks: filenameRenameTracks(for: currentTrackIDs)
        )
        flow.validateRequiredMetadata()
    }

    /// Загружает runtime snapshots для batch rename.
    /// Использует runtime-controller фонотеки как единую точку доступа к snapshot pipeline.
    private func ensureSnapshots(trackIDs: [UUID]) async {
        let limiter = LibraryBatchRenameAsyncLimiter(limit: 6)
        var preparedCount = 0

        /// Фиксирует завершение подготовки одного трека.
        func updatePreparedCount() {
            preparedCount += 1
            flow.updatePreparingRenameProgress(
                preparedCount: preparedCount
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for trackID in trackIDs {
                if snapshotProvider(trackID) != nil {
                    updatePreparedCount()
                    continue
                }

                group.addTask { [weak self] in
                    guard let self else { return }

                    await limiter.acquire()

                    // Loader сам решает, брать snapshot из store или собирать его через builder.
                    _ = await self.snapshotLoader(trackID)
                    await limiter.release()
                }
            }

            for await _ in group {
                updatePreparedCount()
            }
        }
    }

    /// Собирает входные данные для плана переименования в порядке выбранных trackIDs.
    private func filenameRenameTracks(for trackIDs: [UUID]) -> [BatchFilenameRenameTrack] {
        let tracksById = Dictionary(
            uniqueKeysWithValues: tracksProvider()
                .map { ($0.trackId, $0) }
        )

        return trackIDs.compactMap { trackId in
            guard let track = tracksById[trackId] else { return nil }

            let snapshot = snapshotProvider(trackId)

            return BatchFilenameRenameTrack(
                trackId: trackId,
                folderPath: track.fileURL.deletingLastPathComponent().standardizedFileURL.path,
                currentFileName: track.fileURL.lastPathComponent,
                artist: snapshot?.artist ?? track.artist,
                title: snapshot?.title ?? track.title
            )
        }
    }
}
