//
//  TrackListViewModel.swift
//  TrackList
//
//  ViewModel: управление треклистами, треками и состоянием UI импорта
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI

private let selectedTrackListIdKey = "selectedTrackListId"

final class TrackListViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var trackLists: [TrackList] = [] /// Все доступные треклисты (мета + треки)
    @Published var currentListId: UUID { /// Текущий активный плейлист
        didSet {
            UserDefaults.standard.set(currentListId.uuidString, forKey: selectedTrackListIdKey)
        }
    }
    
    @Published var isEditing: Bool = false; /// Режим редактирования
    
    /// Режим импорта: для создания или добавления
    enum ImportMode {
        case none
        case newList
        case addToCurrent
    }
    
    @Published var importMode: ImportMode = .none
    
    // MARK: - Инициализация
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
        }

        loadTracks()
        refreshtrackLists()
    }
    
    /// Перезагружает список всех треклистов с треками
    func refreshtrackLists() {
        let metas = TrackListManager.shared.loadTrackListMetas()
        trackLists = metas.reversed().map { meta in
            let tracks = TrackListManager.shared.loadTracks(for: meta.id)
            return TrackList(id: meta.id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
        }
    }

    /// Выбор треклиста
    func selectTrackList(id: UUID) {
        currentListId = id
        TrackListManager.shared.selectTrackList(id: id)
        loadTracks()
    }

    /// Загрузить треки из текущего выбранного плейлиста
    func loadTracks() {
        guard let list = TrackListManager.shared.getCurrentTrackList() else {
            print("⚠️ Плейлист не выбран")
            return
        }
        self.tracks = list.tracks.map { $0.asTrack() }
        print("✅ Загружено \(tracks.count) треков из \(list.name)")
    }

    /// Импортировать треки в текущий плейлист
    func importTracks(from urls: [URL]) {
        ImportManager().importTracks(from: urls, to: currentListId) { imported in
            var existingTracks = TrackListManager.shared.loadTracks(for: self.currentListId)
            existingTracks.append(contentsOf: imported)
            TrackListManager.shared.saveTracks(existingTracks, for: self.currentListId)

            DispatchQueue.main.async {
                self.tracks = existingTracks.map { $0.asTrack() }
                self.refreshtrackLists()
                print("✅ Импорт завершён: \(imported.count) треков добавлено")
            }
        }
    }

    /// Экспортировать все доступные треки в выбранную папку
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

    /// Очистить текущий плейлист
    func clearTracks() {
        TrackListManager.shared.saveTracks([], for: currentListId)
        self.tracks = []
        print("🧹 Плейлист очищен")
    }

    /// Создаёт новый пустой треклист и делает его активным
    func createEmptyTrackListAndSelect() {
        let newList = TrackListManager.shared.createEmptyTrackList()
        self.currentListId = newList.id
        self.refreshtrackLists()
        self.loadTracks()
    }

    /// Устанавливает флаг на импорт с созданием нового плейлиста
    func startImportForNewTrackList() {
        print("🖋️ Вызов startImportForNewTrackList. ViewModel: \(ObjectIdentifier(self))")
        importMode = .newList
    }

    /// Создаёт новый треклист из выбранных файлов
    func createNewTrackListViaImport(from urls: [URL]) {
        ImportManager().importTracks(from: urls, to: UUID()) { imported in
            guard !imported.isEmpty else {
                print("⚠️ Треки не выбраны, треклист не будет создан")
                return
            }

            let newList = TrackListManager.shared.createTrackList(from: imported)

            DispatchQueue.main.async {
                self.currentListId = newList.id
                self.tracks = imported.map { $0.asTrack() }
                self.refreshtrackLists()
                print("✅ Новый треклист создан с \(imported.count) треками")
            }
        }
    }

    /// Удаление трека по индексам
    func removeTrack(at offsets: IndexSet) {
        var tracks = TrackListManager.shared.loadTracks(for: currentListId)
        tracks.remove(atOffsets: offsets)
        TrackListManager.shared.saveTracks(tracks, for: currentListId)
        self.tracks = tracks.map { $0.asTrack() }
        print("🗑 Удаление завершено")
    }

    /// Переместить треки внутри плейлиста
    func moveTrack(from source: IndexSet, to destination: Int) {
        var tracks = TrackListManager.shared.loadTracks(for: currentListId)
        tracks.move(fromOffsets: source, toOffset: destination)
        TrackListManager.shared.saveTracks(tracks, for: currentListId)
        self.tracks = tracks.map { $0.asTrack() }
        print("🔀 Порядок треков обновлён")
    }
    
    /// Удаляет треклист, обновляет список и выбирает другой при необходимости
    func deleteTrackList(id: UUID) {
        TrackListManager.shared.deleteTrackList(id: id)
        
        // Если удаляем текущий активный треклист — выберем другой
        if id == currentListId {
            let remaining = trackLists.filter { $0.id != id }
            if let first = remaining.first {
                selectTrackList(id: first.id)
            } else {
                // Если ничего не осталось — создаём новый
                let newList = TrackListManager.shared.getOrCreateDefaultTrackList()
                currentListId = newList.id
            }
        }

        refreshtrackLists()
    }
    
    
    
}
