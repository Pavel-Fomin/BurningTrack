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
import SwiftUI

@MainActor
final class TrackListsViewModel: ObservableObject {

    // MARK: - Состояния
    @Published var trackLists: [TrackList] = []
    /// Путь выбранных треклистов для типизированной навигации master-flow.
    @Published var navigationPath: [UUID] = []
    /// Последняя сортировка, выбранная через меню; nil означает ручной порядок.
    @Published private(set) var sortMode: TrackListsSortMode?
    /// Готовое состояние экрана списка треклистов.
    @Published private(set) var screenState = TrackListsScreenState(
        rows: [],
        pendingDeleteTrackListId: nil,
        isShowingDeleteConfirmation: false,
        selectedSortMode: nil
    )
    /// Собирает состояние экрана из текущего списка треклистов.
    private let stateBuilder = TrackListsScreenStateBuilder()
    /// Управляет метаданными списка треклистов.
    private let trackListsManager: any TrackListsManaging
    /// Управляет содержимым одного треклиста.
    private let trackListManager: any TrackListManaging
    /// Показывает пользовательские сообщения об ошибках.
    private let toastPresenter: any ToastPresenting
    /// Управляет сохранёнными настройками отображения списка треклистов.
    private let settingsManager: any SettingsManaging
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
        settingsManager: any SettingsManaging,
        eventProvider: any TrackListsEventProviding
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        self.toastPresenter = toastPresenter
        self.settingsManager = settingsManager
        self.eventProvider = eventProvider
        self.sortMode = settingsManager.settings.internalSettings.trackListsSortMode

        eventProvider.trackListsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    /// Пересобирает состояние экрана с учётом подтверждения удаления.
    private func updateScreenState() {
        let baseState = stateBuilder.build(
            trackLists: trackLists,
            selectedSortMode: sortMode
        )

        screenState = TrackListsScreenState(
            rows: baseState.rows,
            pendingDeleteTrackListId: pendingDeleteTrackListId,
            isShowingDeleteConfirmation: pendingDeleteTrackListId != nil,
            selectedSortMode: baseState.selectedSortMode
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

        let loadedTrackLists = metas.map { meta in
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

    // MARK: - Navigation

    /// Открывает выбранный треклист через состояние навигации.
    func openTrackList(id: UUID) {
        guard trackLists.contains(where: { $0.id == id }) else {
            toastPresenter.handle(AppError.trackListNotFound)
            return
        }

        navigationPath.append(id)
    }

    /// Открывает треклист по внешнему app-level запросу, заменяя текущий detail route.
    func openTrackListFromApp(id: UUID) {
        if trackLists.contains(where: { $0.id == id }) == false {
            refresh()
        }

        guard trackLists.contains(where: { $0.id == id }) else {
            toastPresenter.handle(AppError.trackListNotFound)
            return
        }

        navigationPath = [id]
    }

    /// Возвращает треклист для построения detail-экрана по route id.
    func trackList(for id: UUID) -> TrackList? {
        trackLists.first { $0.id == id }
    }

    // MARK: - Sort

    /// Сортирует треклисты, сохраняет новый фактический порядок в SQLite и показывает caption режима.
    func setSortMode(_ mode: TrackListsSortMode) {
        let previousSortMode = sortMode
        var updatedTrackLists = trackLists

        switch mode {
        case .createdAt:
            updatedTrackLists.sort {
                $0.createdAt > $1.createdAt
            }
        case .name:
            updatedTrackLists.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        do {
            try settingsManager.setTrackListsSortMode(mode)
            try trackListsManager.updateTrackListsOrder(updatedTrackLists.map(\.id))
            trackLists = updatedTrackLists
            sortMode = mode
            updateScreenState()
        } catch let appError as AppError {
            try? settingsManager.setTrackListsSortMode(previousSortMode)
            toastPresenter.handle(appError)
            refresh()
        } catch {
            try? settingsManager.setTrackListsSortMode(previousSortMode)
            toastPresenter.handle(AppError.trackListSaveFailed)
            refresh()
        }
    }

    // MARK: - Reorder

    /// Сохраняет новый порядок треклистов в SQLite и обновляет состояние экрана.
    func moveTrackList(from source: IndexSet, to destination: Int) {
        let previousSortMode = sortMode
        var updatedTrackLists = trackLists
        updatedTrackLists.move(fromOffsets: source, toOffset: destination)

        do {
            try settingsManager.setTrackListsSortMode(nil)
            try trackListsManager.updateTrackListsOrder(updatedTrackLists.map(\.id))
            trackLists = updatedTrackLists
            sortMode = nil
            updateScreenState()
        } catch let appError as AppError {
            try? settingsManager.setTrackListsSortMode(previousSortMode)
            toastPresenter.handle(appError)
            refresh()
        } catch {
            try? settingsManager.setTrackListsSortMode(previousSortMode)
            toastPresenter.handle(AppError.trackListSaveFailed)
            refresh()
        }
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
