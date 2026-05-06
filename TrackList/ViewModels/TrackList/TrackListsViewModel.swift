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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    // MARK: - Загрузка всех треклистов

    func refresh() {
        let metas: [TrackListsManager.TrackListMeta]
        do {
            metas = try TrackListsManager.shared.loadTrackListMetas()
        } catch let appError as AppError {
            self.trackLists = []
            ToastManager.shared.handle(appError)
            return
        } catch {
            self.trackLists = []
            ToastManager.shared.handle(AppError.trackListLoadFailed)
            return
        }

        var trackLoadError: AppError?
        var didFailToLoadTracks = false

        self.trackLists = metas
            .sorted { $0.createdAt > $1.createdAt }
            .map { meta in
                let tracks: [Track]
                do {
                    tracks = try TrackListManager.shared.loadTracks(for: meta.id)
                } catch let appError as AppError {
                    trackLoadError = appError
                    didFailToLoadTracks = true
                    tracks = []
                } catch {
                    didFailToLoadTracks = true
                    tracks = []
                }
                return TrackList(
                    id: meta.id,
                    name: meta.name,
                    createdAt: meta.createdAt,
                    tracks: tracks
                )
            }

        if didFailToLoadTracks {
            ToastManager.shared.handle(trackLoadError ?? AppError.trackListLoadFailed)
        }

        print("📥 Загружено \(trackLists.count) треклистов")
    }


    // MARK: - Удаление

    func deleteTrackList(id: UUID) {
        do {
            try TrackListsManager.shared.deleteTrackList(id: id)
            refresh()
            print("🗑️ Треклист \(id) удалён")
        } catch let appError as AppError {
            ToastManager.shared.handle(appError)
        } catch {
            ToastManager.shared.handle(AppError.trackListSaveFailed)
        }
    }


    // MARK: - Переименование

    func renameTrackList(id: UUID, to newName: String) throws {
        try TrackListsManager.shared.renameTrackList(id: id, to: newName)
        print("✏️ Треклист \(id) переименован в «\(newName)»")
    }


    // MARK: - Редактирование(не используется)

    func toggleEditMode() {
        isEditing.toggle()
    }
}
