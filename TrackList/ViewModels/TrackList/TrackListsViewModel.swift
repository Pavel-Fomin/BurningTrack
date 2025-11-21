//
//  TrackListsViewModel.swift
//  TrackList
//
//  ViewModel для списка всех треклистов
//  - загрузка треклистов (tracklists.json)
//  - удаление,
//  - переименование
//  - обновление UI списка
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

    // MARK: - Загрузка всех треклистов

    func refresh() {
        let metas = TrackListsManager.shared.loadTrackListMetas()

        self.trackLists = metas
            .sorted { $0.createdAt > $1.createdAt }
            .map { meta in
                let tracks = TrackListManager.shared.loadTracks(for: meta.id)
                return TrackList(
                    id: meta.id,
                    name: meta.name,
                    createdAt: meta.createdAt,
                    tracks: tracks
                )
            }

        print("📥 Загружено \(trackLists.count) треклистов")
    }


    // MARK: - Удаление

    func deleteTrackList(id: UUID) {
        TrackListsManager.shared.deleteTrackList(id: id)
        refresh()
        print("🗑️ Треклист \(id) удалён")
    }


    // MARK: - Переименование

    func renameTrackList(id: UUID, to newName: String) {
        TrackListsManager.shared.renameTrackList(id: id, to: newName)
        refresh()
        print("✏️ Треклист \(id) переименован в «\(newName)»")
    }


    // MARK: - Редактирование

    func toggleEditMode() {
        isEditing.toggle()
    }
}
