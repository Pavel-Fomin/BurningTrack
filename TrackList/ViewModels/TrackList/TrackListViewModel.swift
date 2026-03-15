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

@MainActor
final class TrackListViewModel: ObservableObject, TrackMetadataProviding {

    @Published var name: String = ""
    @Published var tracks: [Track] = []
    @Published var currentListId: UUID?
    @Published private(set) var metadataByTrackId: [UUID: TrackMetadataCacheManager.CachedMetadata] = [:]

    // MARK: - Init
    
    init(trackList: TrackList) {
        self.currentListId = trackList.id
        self.name = trackList.name
        self.tracks = trackList.tracks
        
        NotificationCenter.default.addObserver(
            forName: .trackMetadataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let trackId = notification.object as? UUID else { return }

            Task { @MainActor in
                self.reloadMetadata(for: trackId)
            }
        }
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

    private func save() {
        guard let id = currentListId else { return }
        TrackListManager.shared.saveTracks(tracks, for: id)
    }
    
    
    // MARK: - Metadata
    
    // Реализация чтения metadata
    func metadata(for trackId: UUID)
        -> TrackMetadataCacheManager.CachedMetadata?
    {
        metadataByTrackId[trackId]
    }
    
    // Реализация загрузки metadata
    func requestMetadataIfNeeded(for trackId: UUID) {

        if metadataByTrackId[trackId] != nil { return }

        Task {
            guard
                let url = await BookmarkResolver.url(forTrack: trackId),
                let meta = await TrackMetadataCacheManager.shared
                    .loadMetadata(for: url)
            else { return }

            await MainActor.run {
                metadataByTrackId[trackId] = meta
            }
        }
    }
    
    func reloadMetadata(for trackId: UUID) {
        metadataByTrackId[trackId] = nil
        requestMetadataIfNeeded(for: trackId)
    }

    // MARK: - Reorder

    func moveTrack(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        save()
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

            await MainActor.run {
                self.tracks.remove(atOffsets: offsets)
            }
        }
    }

    // MARK: - Clear

    func clearTrackList() {
        guard let id = currentListId else { return }
        TrackListManager.shared.saveTracks([], for: id)
        self.tracks = []
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
