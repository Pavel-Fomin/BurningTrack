//
//  TrackListViewModel.swift
//  TrackList
//
//  Управляет одним треклистом:
//  - загрузка треков по ID
//  - сохранение треков
//  - перемещение
//  - удаление
//  - экспорт
//  - переименование
//
//  Created by Pavel Fomin on 28.04.2025.
//


import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class TrackListViewModel: ObservableObject, TrackMetadataProviding {

    @Published var name: String = ""
    @Published var tracks: [Track] = []
    @Published var currentListId: UUID?
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime snapshot треков по id
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    
    init(trackList: TrackList) {
        self.currentListId = trackList.id
        self.name = trackList.name
        self.tracks = trackList.tracks
        
        NotificationCenter.default.addObserver(
            forName: .trackDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let updateEvent = notification.object as? TrackUpdateEvent else { return }

            Task { @MainActor in
                self.applyTrackUpdateEvent(updateEvent)
            }
        }

        NotificationCenter.default.publisher(for: .trackListTracksDidChange)
            .sink { [weak self] notification in
                guard let changedId = notification.object as? UUID else { return }

                Task { @MainActor in
                    guard let self else { return }
                    guard changedId == self.currentListId else { return }

                    self.loadTracks()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .trackListsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshMeta()
                }
            }
            .store(in: &cancellables)
    }
    
    // Заглушка. Мы ушли от активного треклиста.
    init() { }

    // MARK: - Loading

    func loadTracks() {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран")
            return
        }

        let loadedTracks = TrackListManager.shared.loadTracks(for: id)

        self.tracks = loadedTracks
        print("📥 Загружено \(tracks.count) треков из треклиста \(id)")
    }


    // MARK: - Save

    private func save() -> Bool {
        guard let id = currentListId else { return false }

        let didSave = TrackListManager.shared.saveTracks(tracks, for: id)
        if !didSave {
            PersistentLogger.log("TrackListViewModel: saveTracks failed id=\(id)")
        }
        return didSave
    }
    
    
    // MARK: - Snapshot

    /// Возвращает runtime snapshot трека по его идентификатору.
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: TrackRuntimeSnapshot или nil
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {

        if snapshotsByTrackId[trackId] != nil { return }

        Task {
            let snapshot: TrackRuntimeSnapshot?

            if let storedSnapshot = TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
                snapshot = storedSnapshot
            } else {
                snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
            }

            guard let snapshot else { return }

            await MainActor.run {
                snapshotsByTrackId[trackId] = snapshot
            }
        }
    }

    /// Применяет единое событие обновления трека к состоянию треклиста.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        snapshotsByTrackId[updateEvent.trackId] = updateEvent.snapshot
    }

    // MARK: - Reorder

    func moveTrack(from source: IndexSet, to destination: Int) {
        let previousTracks = tracks
        tracks.move(fromOffsets: source, toOffset: destination)
        guard save() else {
            tracks = previousTracks
            return
        }
        print("↕️ Порядок треков обновлён и сохранён")
    }


    // MARK: - Remove

    func removeTrack(at offsets: IndexSet) {
        guard
            let index = offsets.first,
            let listId = currentListId
        else { return }

        let trackId = tracks[index].id

        Task {
            try await AppCommandExecutor.shared.removeTrackFromTrackList(
                trackId: trackId,
                trackListId: listId
            )
        }
    }

    // MARK: - Clear

    func clearTrackList() {
        guard let id = currentListId else { return }
        guard TrackListManager.shared.saveTracks([], for: id) else {
            PersistentLogger.log("TrackListViewModel: clearTrackList saveTracks failed id=\(id)")
            return
        }
        print("🧹 Треклист очищен")
    }


    // MARK: - Refresh availability

    func refreshTrackAvailability() {
        Task { @MainActor in
            var updated: [Track] = []

            for track in tracks {
                let trackId = track.id
                let isAvailable = await BookmarkResolver.url(forTrack: trackId) != nil

                updated.append(
                    Track(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        fileName: track.fileName,
                        isAvailable: isAvailable
                    )
                )
            }

            self.tracks = updated
            print("♻️ Актуализирована доступность треков через BookmarkResolver")
        }
    }

 
    // MARK: - Refresh meta

    func refreshMeta() {
        guard let id = currentListId else { return }

        let metas = TrackListsManager.shared.loadTrackListMetas()
        guard let meta = metas.first(where: { $0.id == id }) else { return }

        if name != meta.name {
            name = meta.name
        }
    }


    // MARK: - Export

    func exportTracks() {
        guard let topVC = UIApplication.topViewController() else {
            print("❌ Не удалось получить topVC")
            return
        }

        ExportManager.shared.exportViaTempAndPicker(tracks, presenter: topVC)
    }
}


// MARK: - Duration utils

extension TrackListViewModel {
    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad

        if totalDuration >= 86400 {
            formatter.allowedUnits = [.day, .hour, .minute]
            formatter.unitsStyle = .short
        } else if totalDuration >= 3600 {
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short
        } else {
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .positional
        }

        return formatter.string(from: totalDuration) ?? "0:00"
    }
}
