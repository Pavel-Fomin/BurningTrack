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
import Combine

@MainActor
final class TrackListsViewModel: ObservableObject {

    // MARK: - Состояния
    @Published var trackLists: [TrackList] = []
    @Published var isEditing: Bool = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        NotificationCenter.default.publisher(for: .trackListsDidChange)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

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
        print("🗑️ Треклист \(id) удалён")
    }


    // MARK: - Переименование

    func renameTrackList(id: UUID, to newName: String) {
        TrackListsManager.shared.renameTrackList(id: id, to: newName)
        print("✏️ Треклист \(id) переименован в «\(newName)»")
    }


    // MARK: - Редактирование(не используется)

    func toggleEditMode() {
        isEditing.toggle()
    }
}
