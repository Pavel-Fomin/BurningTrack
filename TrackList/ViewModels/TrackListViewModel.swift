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
import UIKit

private let selectedTrackListIdKey = "selectedTrackListId"

final class TrackListViewModel: NSObject, ObservableObject {
    @Published var tracks: [Track] = []
    @Published var trackLists: [TrackList] = [] /// Все доступные треклисты (мета + треки)
    @Published var currentListId: UUID? { /// Текущий активный плейлист
        didSet {
            if let id = currentListId {
                UserDefaults.standard.set(id.uuidString, forKey: selectedTrackListIdKey)
            }
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
    override init() {
        // 1. Установка текущего ID
        let metas = TrackListManager.shared.loadTrackListMetas()
        print("📂 Все треклисты: \(metas.map { "\($0.name) (\($0.id))" })")
        
        if let savedId = UserDefaults.standard.string(forKey: selectedTrackListIdKey),
           let uuid = UUID(uuidString: savedId),
           metas.contains(where: { $0.id == uuid }) {
            print("🧠 Найден сохранённый ID: \(uuid)")
            self.currentListId = uuid
            TrackListManager.shared.selectTrackList(id: uuid)
        } else {
            print("❌ Плейлист не найден")
            // let defaultList = TrackListManager.shared.getOrCreateDefaultTrackList()
            //self.currentListId = defaultList.id
        }
        
        // 2. Вызов super
        super.init()
        
        // 3. Только после super — вызываем методы с self
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
        guard let id = self.currentListId else {
            print("⚠️ Плейлист не выбран — импорт невозможен")
            return
        }
        ImportManager().importTracks(from: urls, to: id) { [weak self] imported in
            guard let self = self, let id = self.currentListId else { return }
            var existingTracks = TrackListManager.shared.loadTracks(for: id)
            existingTracks.insert(contentsOf: imported, at: 0)
            TrackListManager.shared.saveTracks(existingTracks, for: id)
            
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
        
        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(availableTracks, presenter: topVC)
        } else {
            print("❌ Не удалось получить topViewController")
        }
    }
    
    /// Очистить треклист
    func clearTrackList(id: UUID) {
        guard id == currentListId else {
            print("⚠️ Очистка невозможна: плейлист не активен")
            return
        }

        var tracksToClear = TrackListManager.shared.loadTracks(for: id)

        // Удаляем связанные обложки
        for track in tracksToClear {
            if let artworkId = track.artworkId {
                ArtworkManager.deleteArtwork(id: artworkId)
                print("🗑️ Удалена обложка: artwork_\(artworkId).jpg")
            }
        }

        // Очищаем треки
        TrackListManager.shared.saveTracks([], for: id)
        self.tracks = []
        print("🧹 Все треки удалены из плейлиста \(id)")
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
                self.tracks = imported.map { track in
                    let t = track.asTrack()
                    let isAvailable = FileManager.default.fileExists(atPath: t.url.path)
                    return Track(
                        id: t.id,
                        url: t.url,
                        artist: t.artist,
                        title: t.title,
                        duration: t.duration,
                        fileName: t.fileName,
                        artwork: t.artwork,
                        isAvailable: isAvailable
                    )
                }
                self.refreshtrackLists()
                print("✅ Новый треклист создан с \(imported.count) треками")
            }
        }
    }
    
    /// Удаление трека по индексам
    func removeTrack(at offsets: IndexSet) {
        guard let id = currentListId else { return }
        var importedTracks = TrackListManager.shared.loadTracks(for: id)
        
        /// Удаляем обложки
        for index in offsets {
            let track = importedTracks[index]
            if let artworkId = track.artworkId {
                ArtworkManager.deleteArtwork(id: artworkId)
                print("🗑️ Удалена обложка: artwork_\(artworkId).jpg")
            }
        }
        
        /// Удаляем треки
        importedTracks.remove(atOffsets: offsets)
        TrackListManager.shared.saveTracks(importedTracks, for: id)
        self.tracks = importedTracks.map { $0.asTrack() }
        print("🗑 Удаление завершено")
    }
    
    
    /// Переместить треки внутри плейлиста
    func moveTrack(from source: IndexSet, to destination: Int) {
        guard let id = currentListId else { return }
        var tracks = TrackListManager.shared.loadTracks(for: id)
        tracks.move(fromOffsets: source, toOffset: destination)
        TrackListManager.shared.saveTracks(tracks, for: id)
        self.tracks = tracks.map { $0.asTrack() }
        print("🔀 Порядок треков обновлён")
    }
    
    /// Удаляет треклист, обновляет список и выбирает другой при необходимости
    func deleteTrackList(id: UUID) {
        TrackListManager.shared.deleteTrackList(id: id)

        if id == currentListId {
            let metas = TrackListManager.shared.loadTrackListMetas()
            let remaining = metas.filter { $0.id != id }

            if let first = remaining.first {
                selectTrackList(id: first.id)
            } else {
                currentListId = nil
                tracks = []
                print("⚠️ Все треклисты удалены — ничего не выбрано")
            }
        }

        // Обновляем список треклистов
        refreshtrackLists()

        // Проверяем, остались ли треклисты
        if trackLists.isEmpty {
            isEditing = false
            print("✋ Выход из режима редактирования — нет треклистов")
        }
    }
        
        func refreshTrackAvailability() {/// Доступность трека
            self.tracks = self.tracks.map { $0.refreshAvailability() }
            print("♻️ Актуализирована доступность треков")
        }
        
        
        /// Проверяет, можно ли удалить треклист
        func canDeleteTrackList(id: UUID) -> Bool {
            // Выбранный треклист можно удалить если он пустой
            if id == currentListId {
                let tracks = TrackListManager.shared.loadTracks(for: id)
                return tracks.isEmpty
            } else {
                // Невыбранный треклист можно удалить всегда
                return true
            }
        }

    }

    /// Подсчёт времени и длительности треклиста
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

    
    // MARK: - Обработка выбора папки для экспорта
    extension TrackListViewModel: UIDocumentPickerDelegate {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let folderURL = urls.first else {
                print("⚠️ Папка не выбрана")
                return
            }
            
            // Загружаем оригинальные ImportedTrack по ID текущего треклиста
            guard let id = currentListId else {
                print("⚠️ Плейлист не выбран — экспорт невозможен")
                return
            }
            
            let tracks = TrackListManager.shared.loadTracks(for: id)
            let availableTracks = tracks.filter { $0.isAvailable }
            
            if let topVC = UIApplication.topViewController() {
                ExportManager.shared.exportViaTempAndPicker(availableTracks, presenter: topVC)
            }
        }
    }

