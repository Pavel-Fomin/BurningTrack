//
//  TrackListsViewModel.swift
//  TrackList
//
//  ViewModel для списка всех треклистов
//  - загрузку всех треклистов (tracklists.json)
//  - создание, удаление и переименование треклистов
//  - обновление UI при изменениях
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation
import SwiftUI

@MainActor
final class TrackListsViewModel: ObservableObject {
    
    // MARK: - Состояния
    @Published var trackLists: [TrackList] = []
    @Published var isEditing: Bool = false
    
    // MARK: - Загрузка
    
    /// Загружает все треклисты из tracklists.json
    func refresh() {
        let metas = TrackListsManager.shared.loadTrackListMetas()
        self.trackLists = metas.reversed().map { meta in
            let tracks = TrackListManager.shared.loadTracks(for: meta.id)
            return TrackList(id: meta.id,
                             name: meta.name,
                             createdAt: meta.createdAt,
                             tracks: tracks)
        }
        print("📥 Загружено \(trackLists.count) треклистов")
    }
    
    
    // MARK: - Создание
    
    /// Создаёт новый треклист с заданным именем и треками
    func createTrackList(from importedTracks: [ImportedTrack], name: String? = nil) -> TrackList {
        let newList: TrackList
        if let name = name, !name.isEmpty {
            newList = TrackListsManager.shared.createTrackList(from: importedTracks, withName: name)
        } else {
            newList = TrackListsManager.shared.createTrackList(from: importedTracks)
        }
        
        refresh()
        print("✅ Создан новый треклист: \(newList.name)")
        return newList
    }
    
    
    // MARK: - Удаление
    
    /// Удаляет треклист по ID
    func deleteTrackList(id: UUID) {
        TrackListsManager.shared.deleteTrackList(id: id)
        refresh()
        print("🗑️ Треклист \(id) удалён")
    }
    
    
    // MARK: - Переименование
    
    /// Переименовывает треклист по ID
    func renameTrackList(id: UUID, to newName: String) {
        TrackListsManager.shared.renameTrackList(id: id, to: newName)
        refresh()
        print("✏️ Треклист \(id) переименован в «\(newName)»")
    }
    
    
    // MARK: - Режим редактирования
    
    func toggleEditMode() {
        isEditing.toggle()
    }
}
