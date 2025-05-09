//
//  TrackListViewModel.swift
//  TrackList
//
//  Хранение массива треков, добавление, удаление, изменение порядка
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI

private let selectedTrackListIdKey = "selectedTrackListId"

final class TrackListViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    
    
    // MARK: - Все треклисты для отображения
    @Published var allTrackLists: [TrackList] = []

    // MARK: - Обновить список всех треклистов
    func refreshAllTrackLists() {
        let metas = TrackListManager.shared.loadTrackListMetas()
        allTrackLists = metas.map { meta in
            let tracks = TrackListManager.shared.loadTracks(for: meta.id)
            return TrackList(id: meta.id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
        }
    }
    
    // MARK: - Текущий активный ID списка
    @Published var currentListId: UUID {
        didSet {
            UserDefaults.standard.set(currentListId.uuidString, forKey: selectedTrackListIdKey)
        }
    }
    
    init() {
        let metas = TrackListManager.shared.loadTrackListMetas()
        print("📂 Все треклисты: \(metas.map { "\($0.name) (\($0.id))" })")

        if let savedId = UserDefaults.standard.string(forKey: selectedTrackListIdKey),
           let uuid = UUID(uuidString: savedId),
           metas.contains(where: { $0.id == uuid }) {
            print("🧠 Найден сохранённый ID: \(uuid)")
            self.currentListId = uuid
            TrackListManager.shared.selectTrackList(id: uuid)
        } else {
            print("❌ Плейлист не найден — создаём новый")
            let defaultList = TrackListManager.shared.getOrCreateDefaultTrackList()
            self.currentListId = defaultList.id
            // Внутри getOrCreateDefaultTrackList уже вызывается selectTrackList
        }

        loadTracks()
        refreshAllTrackLists()
    }
    
    // MARK: - Управляет выбором текущего треклиста
    func selectTrackList(id: UUID) {
        currentListId = id
        TrackListManager.shared.selectTrackList(id: id)
        loadTracks()
    }
    
    // MARK: - Загрузить треки текущего треклиста
    func loadTracks() {
        guard let list = TrackListManager.shared.getCurrentTrackList() else {
            print("⚠️ Плейлист не выбран")
            return
        }
        self.tracks = list.tracks.map { $0.asTrack() }
        print("✅ Загружено \(tracks.count) треков из \(list.name)")
    }
    
    // MARK: - Импортировать треки в текущий плейлист
    func importTracks(from urls: [URL]) {
        ImportManager().importTracks(from: urls, to: currentListId) { imported in
            // Загружаем текущие треки
            var existingTracks = TrackListManager.shared.loadTracks(for: self.currentListId)

            // Добавляем новые
            existingTracks.append(contentsOf: imported)

            // Сохраняем объединённый список
            TrackListManager.shared.saveTracks(existingTracks, for: self.currentListId)

            DispatchQueue.main.async {
                self.tracks = existingTracks.map { $0.asTrack() }
                self.refreshAllTrackLists()
                print("✅ Импорт завершён: \(imported.count) треков добавлено")
            }
        }
    }
    
    // MARK: - Экспорт треков из текущего плейлиста
    func exportTracks(to folder: URL) {
        guard let list = TrackListManager.shared.getCurrentTrackList() else {
            print("⚠️ Плейлист не выбран")
            return
        }
        
        let availableTracks = list.tracks.filter { $0.isAvailable }
        if availableTracks.isEmpty {
            print("⚠️ Нет доступных треков для экспорта")
            return
        }
        
        ExportManager().exportTracks(availableTracks, to: folder) { result in
            switch result {
            case .success:
                print("✅ Экспорт завершён")
            case .failure(let error):
                print("❌ Ошибка экспорта: \(error)")
            }
        }
    }
    
    
    // MARK: - Очистка треков текущего плейлиста
    func clearTracks() {
        TrackListManager.shared.saveTracks([], for: currentListId)
        self.tracks = []
        print("🧹 Плейлист очищен")
    }
    
    // MARK: - Добавление треклиста в активный треклист
    func createNewTrackListAndSelect() {
        let newList = TrackListManager.shared.createEmptyTrackList()
        self.currentListId = newList.id
        self.refreshAllTrackLists()
        self.loadTracks()
    }
    
    // MARK: - UI-состояния
    enum ImportMode {
        case none
        case newList
        case addToCurrent
    }

    @Published var importMode: ImportMode = .none

    var isImporting: Bool {
        importMode != .none
    }

    // MARK: - UI-действия
    func startImportForNewTrackList() {
        print("🖋️ Вызов startImportForNewTrackList. Текущий trackListViewModel: \(ObjectIdentifier(self))")

        // Сначала сбрасываем (на случай, если файлИмпорт уже открыт)
        importMode = .none

        // Даем SwiftUI обновить состояние
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.importMode = .newList
            print("📂 importMode = .newList (для импорта нового списка). ViewModel: \(ObjectIdentifier(self))")
        }
    }
    
    // MARK: - Создание нового треклиста через импорт
    func createNewTrackListViaImport(from urls: [URL]) {
        // Импортируем треки
        ImportManager().importTracks(from: urls, to: UUID()) { imported in
            guard !imported.isEmpty else {
                print("⚠️ Треки не выбраны, треклист не будет создан")
                return
            }

            // Создаём новый треклист
            let newList = TrackListManager.shared.createTrackList(from: imported)

            DispatchQueue.main.async {
                self.currentListId = newList.id
                self.tracks = imported.map { $0.asTrack() }
                self.refreshAllTrackLists()
                print("✅ Новый треклист создан с \(imported.count) треками")
            }
        }
    }

    // MARK: - Удаление трека
    func removeTrack(at offsets: IndexSet) {
        var tracks = TrackListManager.shared.loadTracks(for: currentListId)
        tracks.remove(atOffsets: offsets)
        TrackListManager.shared.saveTracks(tracks, for: currentListId)
        self.tracks = tracks.map { $0.asTrack() }
        print("🗑 Удаление завершено")
    }

    // MARK: - Перемещение трека
    func moveTrack(from source: IndexSet, to destination: Int) {
        var tracks = TrackListManager.shared.loadTracks(for: currentListId)
        tracks.move(fromOffsets: source, toOffset: destination)
        TrackListManager.shared.saveTracks(tracks, for: currentListId)
        self.tracks = tracks.map { $0.asTrack() }
        print("🔀 Порядок треков обновлён")
    }
}
