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
final class TrackListViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var tracks: [Track] = []
    @Published var currentListId: UUID?

    @Published var isShowingRenameSheet = false
    @Published var toastData: ToastData? = nil
    @Published var isShowingSaveSheet: Bool = false

    // MARK: Init
    init(trackList: TrackList) {
        self.currentListId = trackList.id
        self.name = trackList.name
        self.tracks = trackList.tracks
    }

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


    // MARK: - Reorder

    func moveTrack(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        save()
        print("↕️ Порядок треков обновлён и сохранён")
    }


    // MARK: - Remove

    func removeTrack(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
        save()
        print("🗑️ Трек удалён")
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

                if let url = await TrackRegistry.shared.resolvedURL(for: trackId) {
                    let exists = FileManager.default.fileExists(atPath: url.path)

                    updated.append(
                        Track(
                            id: track.id,
                            title: track.title,
                            artist: track.artist,
                            duration: track.duration,
                            fileName: track.fileName,
                            isAvailable: exists
                        )
                    )
                } else {
                    updated.append(
                        Track(
                            id: track.id,
                            title: track.title,
                            artist: track.artist,
                            duration: track.duration,
                            fileName: track.fileName,
                            isAvailable: false
                        )
                    )
                }
            }

            self.tracks = updated
            print("♻️ Актуализирована доступность треков через TrackRegistry")
        }
    }

    // MARK: - Rename

    func renameCurrentTrackList(to newName: String) {
        guard let id = currentListId else { return }

        guard TrackListManager.shared.validateName(newName) else {
            print("⚠️ Некорректное имя треклиста")
            return
        }

        TrackListsManager.shared.renameTrackList(id: id, to: newName)
        self.name = newName
        print("✏️ Треклист переименован в: \(newName)")

        showToast(message: "Треклист «\(newName)» переименован")
    }


    // MARK: - Export

    func exportTracks() {
        guard let topVC = UIApplication.topViewController() else {
            print("❌ Не удалось получить topVC")
            return
        }

        ExportManager.shared.exportViaTempAndPicker(tracks, presenter: topVC)
    }


    // MARK: - Toast

    func showToast(
        message: String,
        duration: TimeInterval = 2.0
    ) {
        self.toastData = ToastData(
            style: .trackList(name: message),
            artwork: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation { self.toastData = nil }
        }
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
