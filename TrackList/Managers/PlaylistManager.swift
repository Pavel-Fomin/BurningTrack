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
@MainActor
final class PlaylistManager: ObservableObject {
    
    @Published var tracks: [PlayerTrack] = []
    var onTracksChanged: (([PlayerTrack]) -> Void)?
    
    static let shared = PlaylistManager()
    private let databaseStore: PlayerDatabaseStore
    
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
        
        loadQueue()
    }
    
    @objc private func onLibraryAccessRestored() {
        print("🔔 PlaylistManager: libraryAccessRestored → reloadQueue")
        loadQueue()
    }
    
    // MARK: - Загрузка очереди плеера

    /// Загружает очередь плеера из SQLite.
    func loadQueue() {
        do {
            tracks = try databaseStore.fetchQueue()
            let availableCount = tracks.filter { $0.isAvailable }.count
            PersistentLogger.log("📥 PlaylistManager: loaded SQLite player queue tracks=\(tracks.count)")
            print("📥 Загружено \(tracks.count) треков в плеер из SQLite (доступно: \(availableCount))")
        } catch {
            tracks = []
            PersistentLogger.log("⚠️ PlaylistManager: SQLite queue load error \(error)")
            print("⚠️ Ошибка загрузки очереди плеера из SQLite: \(error)")
        }

        // Обновление нужно и после reload, чтобы текущий удалённый элемент не оставался в мини-плеере.
        onTracksChanged?(tracks)
    }

    // MARK: - Сохранение очереди плеера

    /// Сохраняет текущую очередь плеера в SQLite.
    @discardableResult
    func saveQueue() -> Bool {
        do {
            try databaseStore.replaceQueue(tracks)
            // Сообщаем владельцам playback-состояния только после успешной записи очереди.
            onTracksChanged?(tracks)
            PersistentLogger.log("💾 PlaylistManager: saved SQLite player queue items=\(tracks.count)")
            return true
        } catch {
            PersistentLogger.log("❌ PlaylistManager: SQLite queue save error \(error)")
            print("❌ Ошибка сохранения очереди плеера в SQLite: \(error)")
            return false
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

    @discardableResult
    func addTracks(_ tracksToAdd: [PlayerTrack]) -> Bool {
        guard !tracksToAdd.isEmpty else { return true }

        // Откат нужен, чтобы runtime-очередь не расходилась с SQLite при ошибке записи.
        let previousTracks = tracks
        tracks.append(contentsOf: tracksToAdd)

        guard saveQueue() else {
            tracks = previousTracks
            return false
        }

        return true
    }

    @discardableResult
    func addTracks(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }

        // Собираем новые элементы отдельно, чтобы сохранить очередь одним SQLite-обновлением.
        var tracksToAdd: [PlayerTrack] = []
        for trackId in ids {
            let track = await makePlayerTrack(trackId: trackId)
            tracksToAdd.append(track)
        }

        // Откат нужен, чтобы runtime-очередь не расходилась с SQLite при ошибке записи.
        let previousTracks = tracks
        tracks.append(contentsOf: tracksToAdd)

        guard saveQueue() else {
            tracks = previousTracks
            return false
        }

        return true
    }

    // MARK: - Удаление треков

    @discardableResult
    func remove(at index: Int) -> Bool {
        guard index < tracks.count else { return false }
        tracks.remove(at: index)
        return saveQueue()
    }
    
    @discardableResult
    func clear() -> Bool {
        tracks = []
        return saveQueue()
    }
}
