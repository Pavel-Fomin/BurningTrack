//
//  TrackListViewModel.swift
//  TrackList
//
//  ViewModel для управления треклистами и UI-состоянием:
//  - выбор плейлиста
//  - импорт/экспорт треков
//  - очистка, удаление, создание
//  - контроль текущего списка треков и порядка
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI
import UIKit


@MainActor
final class TrackListViewModel: NSObject, ObservableObject {
    
    
    // MARK: - Состояния
    
    @Published var tracks: [Track] = []         /// Текущий список треков
    @Published var trackLists: [TrackList] = [] /// Все доступные треклисты
    @Published var currentListId: UUID?
    @Published var importMode: ImportMode = .none
    @Published var isShowingSaveSheet = false
    @Published var newTrackListName: String = generateDefaultTrackListName()
    @Published var toastData: ToastData? = nil
    @Published var isEditing: Bool = false
    
    init(trackList: TrackList) {
        self.tracks = trackList.tracks.map { $0.asTrack() }
        self.currentListId = trackList.id
    }
    
    override init() {
        super.init()
        self.tracks = []
    }
    
    // Режим импорта треков
    enum ImportMode {
        case none
        case newList
        case addToCurrent
    }
    
    
    
    // MARK: - Треки и треклисты
    
    // Перезагружает список всех треклистов
    func refreshTrackLists() {
        let metas = TrackListManager.shared.loadTrackListMetas()
        trackLists = metas.reversed().map { meta in
            let tracks = TrackListManager.shared.loadTracks(for: meta.id)
            return TrackList(id: meta.id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
        }
    }
    
    // Выбирает треклист и загружает его треки
    func selectTrackList(id: UUID) {
        currentListId = id
        loadTracks()
    }
    
    // Загружает треки для текущего треклиста
    func loadTracks() {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран")
            return
        }
        let imported = TrackListManager.shared.loadTracks(for: id)
        let metas = TrackListManager.shared.loadTrackListMetas()
        if let meta = metas.first(where: { $0.id == id }) {
            let list = TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: imported)
            self.tracks = list.tracks.map { $0.asTrack() }
            print("✅ Загружено \(tracks.count) треков из \(list.name)")
        } else {
            print("⚠️ Метаданные треклиста не найдены")
        }
        
        
        // MARK: - Импорт
        
        // Импортирует треки в текущий треклист
        func importTracks(from urls: [URL]) async {
            guard let id = self.currentListId else {
                print("⚠️ Плейлист не выбран — импорт невозможен")
                return
            }
            
            await ImportManager().importTracks(from: urls, to: id) { imported in
                guard let id = self.currentListId else { return }
                
                var existingTracks = TrackListManager.shared.loadTracks(for: id)
                existingTracks.insert(contentsOf: imported, at: 0)
                TrackListManager.shared.saveTracks(existingTracks, for: id)
                
                DispatchQueue.main.async {
                    self.tracks = existingTracks.map { $0.asTrack() }
                    self.refreshTrackLists()
                    print("✅ Импорт завершён: \(imported.count) треков добавлено")
                }
            }
        }
        
        // Старт нового импорта с созданием треклиста
        func startImportForNewTrackList() {
            print("🖋️ Вызов startImportForNewTrackList. ViewModel: \(ObjectIdentifier(self))")
            importMode = .newList
        }
        
        // Импорт с созданием нового плейлиста
        func createNewTrackListViaImport(from urls: [URL]) async {
            await ImportManager().importTracks(from: urls, to: UUID()) { imported in
                guard !imported.isEmpty else {
                    print("⚠️ Треки не выбраны, треклист не будет создан")
                    return
                }
                
                let newList = TrackListManager.shared.createTrackList(from: imported)
                
                DispatchQueue.main.async {
                    self.currentListId = newList.id
                    self.tracks = imported.map { $0.asTrack().refreshAvailability() }
                    self.refreshTrackLists()
                    print("✅ Новый треклист создан с \(imported.count) треками")
                }
            }
        }
        
        
        // MARK: - Экспорт
        
        // Экспортирует все доступные треки текущего треклиста в выбранную папку
        func exportTracks(to folder: URL) {
            guard let id = currentListId else {
                print("⚠️ Плейлист не выбран")
                return
            }
            let imported = TrackListManager.shared.loadTracks(for: id)
            let metas = TrackListManager.shared.loadTrackListMetas()
            if let meta = metas.first(where: { $0.id == id }) {
                let list = TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: imported)
                self.tracks = list.tracks.map { $0.asTrack() }
                print("✅ Загружено \(tracks.count) треков из \(list.name)")
            } else {
                print("⚠️ Метаданные треклиста не найдены")
            }
        }
        
        
        // MARK: - Работа с треками в плейлисте
        
        // Очистка треклиста
        func clearTrackList(id: UUID) {
            guard id == currentListId else {
                print("⚠️ Очистка невозможна: плейлист не активен")
                return
            }
            
            let tracksToClear = TrackListManager.shared.loadTracks(for: id)
            for track in tracksToClear {
                if let artworkId = track.artworkId {
                    ArtworkManager.deleteArtwork(id: artworkId)
                    print("🗑️ Удалена обложка: artwork_\(artworkId).jpg")
                }
            }
            
            TrackListManager.shared.saveTracks([], for: id)
            self.tracks = []
            print("🧹 Все треки удалены из плейлиста \(id)")
        }
    }
        
        // Перемещение трека
        func moveTrack(from source: IndexSet, to destination: Int) {
            guard let id = currentListId else { return }

            // Меняем порядок в текущем списке
            tracks.move(fromOffsets: source, toOffset: destination)

            // Преобразуем в ImportedTrack
            let imported = tracks.map { $0.asImportedTrack() }

            // Сохраняем обновлённый порядок
            TrackListManager.shared.saveTracks(imported, for: id)

            print("↕️ Треки перемещены и сохранены")
        }
    
    
        // Удаляет трек по индексам
        func removeTrack(at offsets: IndexSet) {
            guard let id = currentListId else { return }

            // Удаляем треки из массива
            tracks.remove(atOffsets: offsets)

            // Преобразуем в ImportedTrack
            let imported = tracks.map { $0.asImportedTrack() }

            // Сохраняем изменения
            TrackListManager.shared.saveTracks(imported, for: id)

        }
        
        
        // MARK: - Треклисты
        
        // Обновляет флаг доступности у каждого трека
        func refreshTrackAvailability() {
            self.tracks = self.tracks.map { $0.refreshAvailability() }
            print("♻️ Актуализирована доступность треков")
        }
        
        // Проверяет, можно ли удалить треклист
        func canDeleteTrackList(id: UUID) -> Bool {
            if id == currentListId {
                let tracks = TrackListManager.shared.loadTracks(for: id)
                return tracks.isEmpty
            } else {
                return true
            }
        }
    
        // Переключение режима редактирования списка треклистов
        func toggleEditMode() {
        isEditing.toggle()
        }
    
        // Запуск импорта нового треклиста
        func startImport() {
        importMode = .newList
        }
    
        func deleteTrackList(id: UUID) {
        TrackListManager.shared.deleteTrackList(id: id)
        refreshTrackLists()
        }
    
        
        // MARK: - Сохранение треклиста
        
        func saveCurrentTrackList(named newName: String) {
            let tracksToSave = self.tracks.map { $0.asImportedTrack() }
            
            let newList = TrackListManager.shared.createTrackList(
                from: tracksToSave,
                withName: newName
            )
            
            self.currentListId = newList.id
            self.tracks = newList.tracks.compactMap { Track(from: $0) }
            self.refreshTrackLists()
            
            print("✅ Новый треклист сохранён: \(newName)")
            showToast(message: "Треклист «\(newName)» сохранён")
        }
        
        // Тост
        func showToast(
            message: String,
            title: String? = nil,
            artist: String? = nil,
            artwork: UIImage? = nil,
            duration: TimeInterval = 2.0
        ) {
            if let title = title, let artist = artist {
                self.toastData = ToastData(
                    style: .track(title: title, artist: artist),
                    artwork: artwork
                    
                )
            } else {
                self.toastData = ToastData(
                    style: .trackList(name: message),
                    artwork: nil
                )
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation {
                    self.toastData = nil
                }
            }
        }
    }
    

    // MARK: - Расширение: длительность плейлиста
    
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
    

    // MARK: - UIDocumentPickerDelegate: экспорт в выбранную папку
    
    extension TrackListViewModel: UIDocumentPickerDelegate {
        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            Task { @MainActor in
                guard urls.first != nil else {
                    print("⚠️ Папка не выбрана")
                    return
                }
                
                guard let id = currentListId else {
                    print("⚠️ Плейлист не выбран — экспорт невозможен")
                    return
                }
                
                let tracks = TrackListManager.shared.loadTracks(for: id)
                let availableTracks = tracks.filter { $0.isAvailable }
                
                if let topVC = UIApplication.topViewController() {
                    ExportManager.shared.exportViaTempAndPicker(
                        availableTracks,
                        presenter: topVC
                    )
                }
            }
        }
    }
    

