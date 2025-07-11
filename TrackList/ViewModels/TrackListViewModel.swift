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

private let selectedTrackListIdKey = "selectedTrackListId"

@MainActor
final class TrackListViewModel: NSObject, ObservableObject {
    
    
    // MARK: - Состояния
    
    @Published var tracks: [Track] = []         /// Текущий список треков
    @Published var trackLists: [TrackList] = [] /// Все доступные треклисты (мета + треки)
    @Published var currentListId: UUID? {       /// Текущий активный плейлист
        didSet {
            if let id = currentListId {
                UserDefaults.standard.set(id.uuidString, forKey: selectedTrackListIdKey)
            }
        }
    }
    
    @Published var isEditing: Bool = false /// Режим редактирования чипсов
    
    // Режим импорта треков
    enum ImportMode {
        case none
        case newList
        case addToCurrent
    }
    
    @Published var importMode: ImportMode = .none
    
    @Published var isShowingSaveSheet = false
    @Published var newTrackListName: String = generateDefaultTrackListName()
    @Published var toastData: ToastData? = nil
    private let trackToastId = UUID()
    
    
    // MARK: - Инициализация
    
    override init() {
        // Инициализация дефолтного треклиста, если ничего нет
        TrackListManager.shared.initializeDefaultTrackListIfNeeded()
        
        let metas = TrackListManager.shared.loadTrackListMetas()
        print("📂 Все треклисты: \(metas.map { "\($0.name) (\($0.id))" })")
        
        if let savedId = UserDefaults.standard.string(forKey: selectedTrackListIdKey),
           let uuid = UUID(uuidString: savedId),
           metas.contains(where: { $0.id == uuid }) {
            print("🧠 Найден сохранённый ID: \(uuid)")
            self.currentListId = uuid
            TrackListManager.shared.selectTrackList(id: uuid)
        } else if let first = metas.first {
            print("⚠️ Сохранённый ID не найден, выбираем первый плейлист: \(first.id)")
            self.currentListId = first.id
            TrackListManager.shared.selectTrackList(id: first.id)
        } else {
            print("❌ Нет доступных треклистов — это критическая ситуация")
        }
        
        super.init()
        
        loadTracks()
        refreshTrackLists()
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
        TrackListManager.shared.selectTrackList(id: id)
        loadTracks()
    }
    
    // Загружает треки для текущего треклиста
    func loadTracks() {
        guard let list = TrackListManager.shared.getCurrentTrackList() else {
            print("⚠️ Плейлист не выбран")
            return
        }
        self.tracks = list.tracks.map { $0.asTrack() }
        print("✅ Загружено \(tracks.count) треков из \(list.name)")
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
    
    
    // MARK: - Работа с треками в плейлисте
    
    // Очистка треклиста (удаление всех треков и обложек)
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
    
    // Удаляет трек по индексам
    func removeTrack(at offsets: IndexSet) {
        guard let id = currentListId else { return }
        
        let metas = TrackListManager.shared.loadTrackListMetas()
        let isDraft = metas.first(where: { $0.id == id })?.isDraft ?? false
        
        var importedTracks = TrackListManager.shared.loadTracks(for: id, isDraft: isDraft)
        
        for index in offsets {
            let track = importedTracks[index]
            if let artworkId = track.artworkId {
                ArtworkManager.deleteArtwork(id: artworkId)
                print("🗑️ Удалена обложка: artwork_\(artworkId).jpg")
            }
        }
        
        importedTracks.remove(atOffsets: offsets)
        TrackListManager.shared.saveTracks(importedTracks, for: id, isDraft: isDraft)
        self.tracks = importedTracks.map { $0.asTrack() }
        print("🗑 Удаление завершено")
    }
    
    // Перемещение трека
    func moveTrack(from source: IndexSet, to destination: Int) {
        guard let id = currentListId else { return }
        
        let metas = TrackListManager.shared.loadTrackListMetas()
        let isDraft = metas.first(where: { $0.id == id })?.isDraft ?? false
        
        var importedTracks = TrackListManager.shared.loadTracks(for: id, isDraft: isDraft)
        
        importedTracks.move(fromOffsets: source, toOffset: destination)
        
        TrackListManager.shared.saveTracks(importedTracks, for: id, isDraft: isDraft)
        self.tracks = importedTracks.map { $0.asTrack() }
        print("↕️ Треки перемещены и сохранены")
    }
    
    
    // MARK: - Треклисты
    
    // Создаёт новый пустой треклист и делает его активным
    func createEmptyTrackListAndSelect() {
        let newList = TrackListManager.shared.createEmptyTrackList()
        self.currentListId = newList.id
        self.refreshTrackLists()
        self.loadTracks()
    }
    
    // Удаляет треклист и выбирает следующий доступный
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
        
        refreshTrackLists()
        
        if trackLists.isEmpty {
            isEditing = false
            print("✋ Выход из режима редактирования — нет треклистов")
        }
    }
    
    
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
    
    
    // MARK: - Сохранение треклиста
    
    func saveCurrentTrackList(named newName: String) {
        let tracksToSave = self.tracks.map { $0.asImportedTrack() }
        
        let newList = TrackListManager.shared.createTrackList(
            from: tracksToSave,
            withName: newName
        )
        
        self.currentListId = newList.id
        self.tracks = newList.tracks.map { Track(from: $0) }
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

