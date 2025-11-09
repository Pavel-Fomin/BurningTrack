//
//  TrackListViewModel.swift
//  TrackList
//
//  ViewModel для управления треклистом и UI-состоянием:
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
    
    @Published var name: String = ""
    @Published var tracks: [Track] = []         /// Текущий список треков
    @Published var currentListId: UUID?
    @Published var importMode: ImportMode = .none
    @Published var isShowingSaveSheet = false
    @Published var newTrackListName: String = generateDefaultTrackListName()
    @Published var toastData: ToastData? = nil
    @Published var isEditing: Bool = false
    @Published var artworkByURL: [URL: UIImage] = [:]
    @Published var isShowingRenameSheet = false
    
    init(trackList: TrackList) {
        self.tracks = trackList.tracks.map { $0.asTrack() }
        self.currentListId = trackList.id
        self.name = trackList.name
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
    
    var isNameValid: Bool {
        TrackListManager.shared.validateName(name)
    }
    
    
    // MARK: - Треклист
    
    func selectTrackList(id: UUID) {
        currentListId = id
        loadTracks()
    }
    
    func loadTracks() {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран")
            return
        }
        let imported = TrackListManager.shared.loadTracks(for: id)
        let metas = TrackListsManager.shared.loadTrackListMetas()
        if let meta = metas.first(where: { $0.id == id }) {
            let list = TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: imported)
            self.tracks = list.tracks.map { $0.asTrack() }
            print("✅ Загружено \(tracks.count) треков из \(list.name)")
        } else {
            print("⚠️ Метаданные треклиста не найдены")
        }
    }
    
    
    // MARK: - Импорт
    
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
                print("✅ Импорт завершён: \(imported.count) треков добавлено")
            }
        }
    }
    
    func startImportForNewTrackList() {
        print("🖋️ Вызов startImportForNewTrackList. ViewModel: \(ObjectIdentifier(self))")
        importMode = .newList
    }
    
    func createNewTrackListViaImport(from urls: [URL]) async {
        await ImportManager().importTracks(from: urls, to: UUID()) { imported in
            guard !imported.isEmpty else {
                print("⚠️ Треки не выбраны, треклист не будет создан")
                return
            }
            
            let newList = TrackListsManager.shared.createTrackList(from: imported)
            
            DispatchQueue.main.async {
                self.currentListId = newList.id
                self.tracks = imported.map { $0.asTrack().refreshAvailability() }
                print("✅ Новый треклист создан с \(imported.count) треками")
            }
        }
    }
    
    
    // MARK: - Экспорт
    
    func exportTracks(to folder: URL) {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран")
            return
        }
        let imported = TrackListManager.shared.loadTracks(for: id)
        let metas = TrackListsManager.shared.loadTrackListMetas()
        if let meta = metas.first(where: { $0.id == id }) {
            let list = TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: imported)
            self.tracks = list.tracks.map { $0.asTrack() }
            print("✅ Загружено \(tracks.count) треков из \(list.name)")
        } else {
            print("⚠️ Метаданные треклиста не найдены")
        }
    }
    
    
    // MARK: - Работа с треками в плейлисте
    
    func clearTrackList(id: UUID) {
        guard id == currentListId else {
            print("⚠️ Очистка невозможна: плейлист не активен")
            return
        }
        
        TrackListManager.shared.saveTracks([], for: id)
        self.tracks = []
        print("🧹 Все треки удалены из плейлиста \(id)")
    }

    func moveTrack(from source: IndexSet, to destination: Int) {
        guard let id = currentListId else { return }
        tracks.move(fromOffsets: source, toOffset: destination)
        let imported = tracks.map { $0.asImportedTrack() }
        TrackListManager.shared.saveTracks(imported, for: id)
        print("↕️ Треки перемещены и сохранены")
    }

    func removeTrack(at offsets: IndexSet) {
        guard let id = currentListId else { return }
        tracks.remove(atOffsets: offsets)
        let imported = tracks.map { $0.asImportedTrack() }
        TrackListManager.shared.saveTracks(imported, for: id)
    }
    
    
    // MARK: - Треклисты
    
    func refreshTrackAvailability() {
        self.tracks = self.tracks.map { $0.refreshAvailability() }
        print("♻️ Актуализирована доступность треков")
    }
    
    func canDeleteTrackList(id: UUID) -> Bool {
        if id == currentListId {
            let tracks = TrackListManager.shared.loadTracks(for: id)
            return tracks.isEmpty
        } else {
            return true
        }
    }
    
    
    func startImport() {
        importMode = .newList
    }
    
    
    // MARK: - Сохранение треклиста
    
    func saveCurrentTrackList(named newName: String) {
        let tracksToSave = self.tracks.map { $0.asImportedTrack() }
        let newList = TrackListsManager.shared.createTrackList(from: tracksToSave, withName: newName)
        self.currentListId = newList.id
        self.tracks = newList.tracks.compactMap { Track(from: $0) }
        print("✅ Новый треклист сохранён: \(newName)")
        showToast(message: "Треклист «\(newName)» сохранён")
    }
    
    
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
    
    // MARK: - Переименование треклиста

    func renameCurrentTrackList(to newName: String) {
        guard let id = currentListId else {
            print("⚠️ Плейлист не выбран — переименование невозможно")
            return
        }
        guard TrackListManager.shared.validateName(newName) else {
            print("⚠️ Некорректное имя треклиста")
            return
        }

        var metas = TrackListsManager.shared.loadTrackListMetas()
        guard let index = metas.firstIndex(where: { $0.id == id }) else {
            print("⚠️ Метаданные треклиста не найдены для id \(id)")
            return
        }

        metas[index].name = newName
        TrackListsManager.shared.saveTrackListMetas(metas)

        self.name = newName
        print("✏️ Треклист переименован в «\(newName)»")
        showToast(message: "Треклист «\(newName)» переименован")
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
