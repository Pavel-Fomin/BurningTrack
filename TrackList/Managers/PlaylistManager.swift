//
//  PlaylistManager.swift
//  TrackList
//
//  Загружает и хранит очередь плеера через SQLite
//
//  Created by Pavel Fomin on 15.07.2025.
//
import Foundation
import SwiftUI

/// Receipt подтверждённой SQLite-записи очереди плеера.
struct PlayerQueueSaveReceipt: Sendable, Equatable {
    let itemsCount: Int
    let mutationVersion: UInt64
}

/// Разделяет сохранённое изменение очереди и команду, которой нечего менять.
enum PlayerQueueMutationOutcome: Sendable, Equatable {
    case confirmed(PlayerQueueSaveReceipt)
    case unchanged
}

@MainActor
final class PlaylistManager: ObservableObject {

    /// Различает штатную начальную загрузку и reload после восстановления доступа к фонотеке.
    private enum QueueLoadReason: String {
        case initial = "init"
        case libraryAccessRestored
    }
    
    @Published var tracks: [PlayerTrack] = []
    var onTracksChanged: (([PlayerTrack]) -> Void)?
    
    static let shared = PlaylistManager()
    private let databaseStore: any PlayerQueuePersisting
    /// Версия повышается только после успешного сохранения пользовательского изменения очереди.
    private var queueMutationVersion: UInt64 = 0
    
    private init() {
        do {
            self.databaseStore = try PlayerDatabaseStore()
        } catch {
            preconditionFailure("Не удалось создать PlayerDatabaseStore: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLibraryAccessRestored),
            name: .libraryAccessRestored,
            object: nil
        )
        
        loadQueue(reason: .initial)
    }

    /// Создаёт изолированный Manager для автоматических проверок без подписки на глобальное notification-событие.
    init(
        databaseStore: any PlayerQueuePersisting,
        loadsInitialQueue: Bool = true
    ) {
        self.databaseStore = databaseStore

        if loadsInitialQueue {
            loadQueue(reason: .initial)
        }
    }
    
    @objc private func onLibraryAccessRestored() {
        print("🔔 PlaylistManager: libraryAccessRestored → reloadQueue")
        reloadQueueAfterLibraryAccessRestored()
    }
    
    // MARK: - Загрузка очереди плеера

    /// Восстанавливает сохранённую очередь только пока пользователь не изменил её в текущем запуске.
    func reloadQueueAfterLibraryAccessRestored() {
        guard queueMutationVersion == 0 else {
            PersistentLogger.log(
                "PlaylistManager queue loadQueue skipped " +
                    "reason=libraryAccessRestored queueMutationVersion=\(queueMutationVersion)"
            )
            return
        }

        loadQueue(reason: .libraryAccessRestored)
    }

    /// Загружает очередь плеера из SQLite.
    private func loadQueue(reason: QueueLoadReason) {
        let runtimeCountBefore = tracks.count
        let loadMutationVersion = queueMutationVersion
        PersistentLogger.log(
            "PlaylistManager queue loadQueue started " +
                "reason=\(reason.rawValue) runtimeCountBefore=\(runtimeCountBefore) " +
                "queueMutationVersion=\(loadMutationVersion)"
        )

        var didApplyLoadedQueue = false
        do {
            let loadedTracks = try databaseStore.fetchQueue()

            if queueMutationVersion != loadMutationVersion {
                PersistentLogger.log(
                    "PlaylistManager queue loadQueue discarded stale result " +
                        "reason=\(reason.rawValue) loadMutationVersion=\(loadMutationVersion) " +
                        "currentMutationVersion=\(queueMutationVersion) loadedCount=\(loadedTracks.count)"
                )
            } else {
                tracks = loadedTracks
                didApplyLoadedQueue = true
                let availableCount = tracks.filter { $0.isAvailable }.count
                PersistentLogger.log(
                    "PlaylistManager queue loadQueue loaded " +
                        "reason=\(reason.rawValue) loadedCount=\(tracks.count)"
                )
                PersistentLogger.log("📥 PlaylistManager: loaded SQLite player queue tracks=\(tracks.count)")
                print("📥 Загружено \(tracks.count) треков в плеер из SQLite (доступно: \(availableCount))")
            }
        } catch {
            PersistentLogger.log(
                "PlaylistManager queue loadQueue error " +
                    "reason=\(reason.rawValue) error=\(error)"
            )
            print("⚠️ Ошибка загрузки очереди плеера из SQLite: \(error)")
            PersistentLogger.log("⚠️ PlaylistManager: SQLite queue load error \(error)")
        }

        PersistentLogger.log(
            "PlaylistManager queue loadQueue completed " +
                "reason=\(reason.rawValue) applied=\(didApplyLoadedQueue) " +
                "runtimeCountAfter=\(tracks.count)"
        )

        if didApplyLoadedQueue {
            // Обновление нужно после применённого reload, чтобы удалённый элемент не оставался в мини-плеере.
            onTracksChanged?(tracks)
        }
    }

    // MARK: - Сохранение очереди плеера

    /// Сохраняет текущую очередь плеера в SQLite и подтверждает новую версию только после persist.
    func saveQueue() throws -> PlayerQueueSaveReceipt {
        do {
            try databaseStore.replaceQueue(tracks)
            queueMutationVersion &+= 1
            // Сообщаем владельцам playback-состояния только после успешной записи очереди.
            onTracksChanged?(tracks)
            PersistentLogger.log(
                "💾 PlaylistManager: saved SQLite player queue items=\(tracks.count) " +
                    "queueMutationVersion=\(queueMutationVersion)"
            )
            return PlayerQueueSaveReceipt(
                itemsCount: tracks.count,
                mutationVersion: queueMutationVersion
            )
        } catch {
            PersistentLogger.log("❌ PlaylistManager: SQLite queue save error \(error)")
            print("❌ Ошибка сохранения очереди плеера в SQLite: \(error)")
            throw AppError.playlistSaveFailed
        }
    }
    
    // MARK: - Создание library-трека для очереди

    /// Создаёт элемент очереди library-трека из актуального URL и runtime-метаданных.
    private func makePlayerTrack(
        trackId: UUID,
        queueItemId: UUID = UUID()
    ) async -> PlayerTrack {
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return PlayerTrack(
                queueItemId: queueItemId,
                trackId: trackId,
                title: nil,
                artist: nil,
                duration: 0,
                fileName: "",
                isAvailable: false
            )
        }
        let fileName = url.lastPathComponent
        let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url)
        let title = metadata?.title ?? url.deletingPathExtension().lastPathComponent
        let artist = metadata?.artist
        let album = metadata?.album
        let duration = metadata?.duration ?? 0
        let isAvailable = true
        let source = await TrackRegistry.shared.entry(for: trackId)?.source ?? .library
        return PlayerTrack(
            queueItemId: queueItemId,
            trackId: trackId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable,
            source: source
        )
    }
    
    // MARK: - Добавление треков в плеер

    /// Добавляет элементы и возвращает confirmed только после сохранения полной очереди.
    func addTracks(_ tracksToAdd: [PlayerTrack]) throws -> PlayerQueueMutationOutcome {
        let tracksCountBefore = tracks.count
        PersistentLogger.log(
            "PlaylistManager queue addTracks started " +
                "tracksToAddCount=\(tracksToAdd.count) tracksCountBefore=\(tracksCountBefore)"
        )

        guard !tracksToAdd.isEmpty else {
            PersistentLogger.log(
                "PlaylistManager queue addTracks completed " +
                    "saveQueueResult=notRequired tracksCountAfter=\(tracks.count)"
            )
            return .unchanged
        }

        // Откат нужен, чтобы runtime-очередь не расходилась с SQLite при ошибке записи.
        let previousTracks = tracks
        tracks.append(contentsOf: tracksToAdd)
        PersistentLogger.log(
            "PlaylistManager queue addTracks appended " +
                "tracksCountAfterAppend=\(tracks.count)"
        )

        do {
            let receipt = try saveQueue()
            PersistentLogger.log(
                "PlaylistManager queue addTracks saveQueue result=confirmed"
            )
            PersistentLogger.log(
                "PlaylistManager queue addTracks completed " +
                    "saveQueueResult=confirmed tracksCountAfter=\(tracks.count)"
            )
            return .confirmed(receipt)
        } catch {
            tracks = previousTracks
            PersistentLogger.log(
                "PlaylistManager queue addTracks completed " +
                    "saveQueueResult=failed tracksCountAfter=\(tracks.count)"
            )
            throw error
        }
    }

    /// Добавляет библиотечные элементы и возвращает confirmed только после сохранения полной очереди.
    func addTracks(ids: [UUID]) async throws -> PlayerQueueMutationOutcome {
        guard !ids.isEmpty else { return .unchanged }

        // Собираем новые элементы отдельно, чтобы сохранить очередь одним SQLite-обновлением.
        var tracksToAdd: [PlayerTrack] = []
        for trackId in ids {
            let track = await makePlayerTrack(trackId: trackId)
            tracksToAdd.append(track)
        }

        // Откат нужен, чтобы runtime-очередь не расходилась с SQLite при ошибке записи.
        let previousTracks = tracks
        tracks.append(contentsOf: tracksToAdd)

        do {
            return .confirmed(try saveQueue())
        } catch {
            tracks = previousTracks
            throw error
        }
    }

    // MARK: - Удаление треков

    /// Удаляет элемент и восстанавливает runtime-очередь, если SQLite persist не подтверждён.
    func remove(at index: Int) throws -> PlayerQueueMutationOutcome {
        guard index < tracks.count else {
            throw AppError.trackNotFound
        }
        let previousTracks = tracks
        tracks.remove(at: index)
        do {
            return .confirmed(try saveQueue())
        } catch {
            tracks = previousTracks
            throw error
        }
    }
    
    @discardableResult
    func clear() throws -> PlayerQueueMutationOutcome {
        guard tracks.isEmpty == false else {
            return .unchanged
        }
        let previousTracks = tracks
        tracks = []
        do {
            return .confirmed(try saveQueue())
        } catch {
            tracks = previousTracks
            throw error
        }
    }
}
