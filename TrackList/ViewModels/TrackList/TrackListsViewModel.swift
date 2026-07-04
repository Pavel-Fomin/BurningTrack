//
//  TrackListsViewModel.swift
//  TrackList
//
//  ViewModel для списка всех треклистов
//  - загрузка треклистов через manager-слой
//  - удаление
//  - обновление UI списка
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation
import Combine

@MainActor
final class TrackListsViewModel: ObservableObject {

    // MARK: - Состояния
    @Published var trackLists: [TrackList] = []
    /// Готовое состояние экрана списка треклистов.
    @Published private(set) var screenState = TrackListsScreenState(
        rows: [],
        pendingDeleteTrackListId: nil,
        isShowingDeleteConfirmation: false
    )
    /// Собирает состояние экрана из текущего списка треклистов.
    private let stateBuilder = TrackListsScreenStateBuilder()
    /// Управляет метаданными списка треклистов.
    private let trackListsManager: any TrackListsManaging
    /// Управляет содержимым одного треклиста.
    private let trackListManager: any TrackListManaging
    /// Показывает пользовательские сообщения об ошибках.
    private let toastPresenter: any ToastPresenting
    /// Поставляет события изменения списка треклистов.
    private let eventProvider: any TrackListsEventProviding
    /// Идентификатор треклиста, ожидающего подтверждения удаления.
    private var pendingDeleteTrackListId: UUID?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        trackListsManager: any TrackListsManaging,
        trackListManager: any TrackListManaging,
        toastPresenter: any ToastPresenting,
        eventProvider: any TrackListsEventProviding
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        self.toastPresenter = toastPresenter
        self.eventProvider = eventProvider

        eventProvider.trackListsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    /// Пересобирает состояние экрана с учётом подтверждения удаления.
    private func updateScreenState() {
        let baseState = stateBuilder.build(trackLists: trackLists)

        screenState = TrackListsScreenState(
            rows: baseState.rows,
            pendingDeleteTrackListId: pendingDeleteTrackListId,
            isShowingDeleteConfirmation: pendingDeleteTrackListId != nil
        )
    }

    // MARK: - Загрузка всех треклистов

    /// Загружает треклисты и обрабатывает ошибки чтения данных.
    private func loadTrackLists() -> [TrackList] {
        let metas: [TrackListMeta]
        do {
            metas = try trackListsManager.loadTrackListMetas()
        } catch let appError as AppError {
            toastPresenter.handle(appError)
            return []
        } catch {
            toastPresenter.handle(AppError.trackListLoadFailed)
            return []
        }

        var trackLoadError: AppError?
        var didFailToLoadTracks = false

        let loadedTrackLists = metas
            .sorted { $0.createdAt > $1.createdAt }
            .map { meta in
                let tracks: [Track]
                do {
                    tracks = try trackListManager.loadTracks(for: meta.id)
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
            toastPresenter.handle(trackLoadError ?? AppError.trackListLoadFailed)
        }

        return loadedTrackLists
    }

    func refresh() {
        self.trackLists = loadTrackLists()
        updateScreenState()

        print("📥 Загружено \(trackLists.count) треклистов")
    }


    // MARK: - Удаление

    /// Запрашивает подтверждение удаления треклиста.
    func requestDeleteTrackList(id: UUID) {
        pendingDeleteTrackListId = id
        updateScreenState()
    }

    /// Отменяет подтверждение удаления треклиста.
    func cancelDeleteTrackList() {
        pendingDeleteTrackListId = nil
        updateScreenState()
    }

    func deleteTrackList(id: UUID) {
        do {
            try trackListsManager.deleteTrackList(id: id)
            pendingDeleteTrackListId = nil
            refresh()
            print("🗑️ Треклист \(id) удалён")
        } catch let appError as AppError {
            toastPresenter.handle(appError)
        } catch {
            toastPresenter.handle(AppError.trackListSaveFailed)
        }
    }
}
