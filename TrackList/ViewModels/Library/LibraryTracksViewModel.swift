//
//  LibraryTracksViewModel.swift
//  TrackList
//
//  ViewModel для треков внутри папки
//  Отвечает за данные треков и операции над ними
//
//  Created by Pavel Fomin on 12.12.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LibraryTracksViewModel: ObservableObject {

    // MARK: - Входные данные

    let folderId: UUID

    // MARK: - Состояния

    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]
    @Published var isLoading: Bool = false

    @Published private(set) var didLoad: Bool = false
    @Published private(set) var didLoadTrackListNames = false

    // MARK: - Subscriptions

    private var trackListsObserver: NSObjectProtocol?

    // MARK: - Init

    init(folderId: UUID) {
        self.folderId = folderId
        subscribeToTrackLists()
    }

    deinit {
        if let o = trackListsObserver {
            NotificationCenter.default.removeObserver(o)
        }
        print("🧹 deinit LibraryTracksViewModel")
    }

    // MARK: - Load

    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Получаем entry треков из TrackRegistry
        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)

        // 2. Преобразуем в LibraryTrack
        var tracks: [LibraryTrack] = []
        tracks.reserveCapacity(entries.count)

        for entry in entries {
            if let url = await BookmarkResolver.url(forTrack: entry.id) {

                // Дата файла: contentModificationDate / creationDate
                var fileDate = entry.updatedAt
                if let values = try? url.resourceValues(
                    forKeys: [.contentModificationDateKey, .creationDateKey]
                ) {
                    fileDate =
                        values.contentModificationDate ??
                        values.creationDate ??
                        entry.updatedAt
                }

                tracks.append(
                    LibraryTrack(
                        id: entry.id,
                        fileURL: url,
                        title: nil,
                        artist: nil,
                        duration: 0,
                        addedDate: fileDate
                    )
                )
            }
        }

        // 3. Группируем по датам изменения файла
        let grouped = Self.groupTracksByDate(tracks)

        // 4. UI
        await MainActor.run {
            self.trackSections = grouped
            self.loadTrackListNamesByURL()
        }
    }

    // MARK: - TrackList Badges

    func loadTrackListNamesIfNeeded() {
        guard !didLoadTrackListNames else { return }
        didLoadTrackListNames = true
        loadTrackListNamesByURL()
    }

    func loadTrackListNamesByURL() {
        Task { @MainActor in

            // Собираем все ID треков на экране
            var idsInView: [UUID] = []
            for section in trackSections {
                for track in section.tracks {
                    idsInView.append(track.id)
                }
            }

            var namesById: [UUID: Set<String>] = [:]

            // Загружаем все треклисты
            let metas = TrackListsManager.shared.loadTrackListMetas()

            for meta in metas {
                let list = TrackListManager.shared.getTrackListById(meta.id)
                for t in list.tracks {
                    namesById[t.id, default: []].insert(meta.name)
                }
            }

            // Формируем финальный словарь
            var result: [UUID: [String]] = [:]
            for id in idsInView {
                let names = namesById[id] ?? []
                result[id] = Array(names).sorted()
            }

            self.trackListNamesById = result
        }
    }

    // MARK: - Metadata

    func setMetadata(
        _ meta: TrackMetadataCacheManager.CachedMetadata,
        for url: URL
    ) {
        metadataByURL[url] = meta
    }

    // MARK: - File operations

    func moveTrack(
        _ trackId: UUID,
        toFolder folderId: UUID,
        playerManager: PlayerManager
    ) async {
        do {
            try await LibraryFileManager.shared.moveTrack(
                id: trackId,
                toFolder: folderId,
                using: playerManager
            )

            await refresh()
            print("📁 Трек успешно перемещён \(trackId) → папка \(folderId)")

        } catch {
            print("❌ Ошибка перемещения трека: \(error.localizedDescription)")
        }
    }

    func renameTrack(
        _ trackId: UUID,
        to newFileName: String,
        playerManager: PlayerManager
    ) async {
        do {
            try await LibraryFileManager.shared.renameTrack(
                id: trackId,
                to: newFileName,
                using: playerManager
            )

            await refresh()
            print("✏️ Трек переименован \(trackId) → \(newFileName)")

        } catch {
            print("❌ Ошибка переименования трека: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscriptions

    private func subscribeToTrackLists() {
        trackListsObserver = NotificationCenter.default.addObserver(
            forName: .trackListsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadTrackListNamesByURL()
            }
        }
    }

    // MARK: - Support

    nonisolated static func groupTracksByDate(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {

        let calendar = Calendar.current

        let grouped = Dictionary(grouping: tracks) {
            calendar.startOfDay(for: $0.addedDate)
        }

        let sortedDays = grouped.keys.sorted(by: >)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        return sortedDays.map { day in
            let sectionTitle: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                return dateFormatter.string(from: day)
            }()

            let items = (grouped[day] ?? []).sorted {
                ($0.addedDate, $0.url.lastPathComponent) >
                ($1.addedDate, $1.url.lastPathComponent)
            }

            return TrackSection(
                id: day.ISO8601String,
                title: sectionTitle,
                tracks: items
            )
        }
    }
}

private extension Date {
    var ISO8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
