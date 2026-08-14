//
//  TrackListsViewModel.swift
//  TrackList
//
//  Состояние master-flow списка треклистов.
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class TrackListsViewModel: ObservableObject {

    // MARK: - Состояния

    /// Последний успешно загруженный полный master-снимок.
    @Published private(set) var trackLists: [TrackList] = []
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

    /// Идентификатор треклиста, ожидающего подтверждения удаления.
    private var pendingDeleteTrackListId: UUID?
    /// Защищает общий master-flow от повторной начальной загрузки при смене корневой компоновки.
    private(set) var hasLoadedTrackLists = false

    // MARK: - Зависимости

    /// Загружает полный master-снимок без передачи ViewModel mutation-контрактов.
    private let loader: any TrackListsLoading
    /// Показывает только ошибки автоматической загрузки, не раскрывая ViewModel общий Toast API.
    private let loadFailurePresenter: any TrackListsLoadFailurePresenting
    /// Поставляет invalidation-события изменения списка треклистов.
    private let eventProvider: any TrackListsEventProviding
    /// Возвращает iPad sidebar в master, если внешний reload удалил выбранный detail.
    private let navigationPruning: any TrackListsNavigationPruning
    /// Собирает готовое состояние экрана из текущего master-снимка.
    private let stateBuilder = TrackListsScreenStateBuilder()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    init(
        loader: any TrackListsLoading,
        initialSortMode: TrackListsSortMode?,
        loadFailurePresenter: any TrackListsLoadFailurePresenting,
        eventProvider: any TrackListsEventProviding,
        navigationPruning: any TrackListsNavigationPruning
    ) {
        self.loader = loader
        self.sortMode = initialSortMode
        self.loadFailurePresenter = loadFailurePresenter
        self.eventProvider = eventProvider
        self.navigationPruning = navigationPruning

        eventProvider.trackListsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // Событие является invalidation, поэтому ViewModel перечитывает полный согласованный снимок.
                self?.reloadTrackLists()
            }
            .store(in: &cancellables)
    }

    // MARK: - Загрузка

    /// Загружает master-снимок при первом появлении; ошибка не блокирует следующую попытку.
    @discardableResult
    func loadTrackListsIfNeeded() -> Bool {
        guard hasLoadedTrackLists == false else {
            return true
        }

        return reloadTrackLists()
    }

    /// Перечитывает snapshot после invalidation, сохраняя последний успешный state при ошибке.
    @discardableResult
    func reloadTrackLists() -> Bool {
        do {
            applyLoadedTrackLists(try loader.loadTrackLists())
            return true
        } catch let appError as AppError {
            loadFailurePresenter.presentTrackListsLoadFailure(appError)
            return false
        } catch {
            loadFailurePresenter.presentTrackListsLoadFailure(.trackListLoadFailed)
            return false
        }
    }

    /// Публикует новый полный snapshot только после успешной загрузки всех зависимых данных detail-flow.
    func applyLoadedTrackLists(_ loadedTrackLists: [TrackList]) {
        trackLists = displayOrderedTrackLists(from: loadedTrackLists)
        hasLoadedTrackLists = true
        pruneNavigation(validTrackListIDs: Set(trackLists.map(\.id)))
        updateScreenState()
    }

    // MARK: - Состояние представления

    /// Применяет уже атомарно сохранённый порядок до публикации invalidation-события.
    func applyPersistedOrdering(
        _ orderedTrackLists: [TrackList],
        sortMode mode: TrackListsSortMode?
    ) {
        sortMode = mode
        trackLists = displayOrderedTrackLists(from: orderedTrackLists)
        updateScreenState()
    }

    /// Запоминает ожидающий удаления regular-треклист после валидации user-команды в handler.
    func requestDeleteTrackList(id: UUID) {
        pendingDeleteTrackListId = id
        updateScreenState()
    }

    /// Скрывает подтверждение удаления, не меняя master-снимок.
    func cancelDeleteTrackList() {
        pendingDeleteTrackListId = nil
        updateScreenState()
    }

    /// Проверяет, относится ли подтверждение к ещё актуальному запросу удаления.
    func isDeleteRequested(for id: UUID) -> Bool {
        pendingDeleteTrackListId == id
    }

    // MARK: - Навигация

    /// Добавляет уже проверенный route пользовательского открытия в compact navigation stack.
    func appendNavigationPath(id: UUID) {
        navigationPath.append(id)
    }

    /// Заменяет detail route внешним app-level запросом.
    func replaceNavigationPath(with id: UUID) {
        navigationPath = [id]
    }

    /// Возвращает треклист для построения detail-экрана по route id.
    func trackList(for id: UUID) -> TrackList? {
        trackLists.first { $0.id == id }
    }

    /// Проверяет, существует ли треклист в последнем успешно загруженном master-снимке.
    func containsTrackList(id: UUID) -> Bool {
        trackList(for: id) != nil
    }

    // MARK: - Приватное

    /// Применяет выбранную сортировку после каждого reload, чтобы settings и отображение не расходились после create/rename.
    private func displayOrderedTrackLists(from trackLists: [TrackList]) -> [TrackList] {
        guard let sortMode else {
            return TrackListsSortMode.manualOrder(from: trackLists)
        }

        return sortMode.applying(to: trackLists)
    }

    /// Убирает маршруты и iPad detail, которые больше не существуют в опубликованном snapshot.
    private func pruneNavigation(validTrackListIDs: Set<UUID>) {
        navigationPath.removeAll { validTrackListIDs.contains($0) == false }
        navigationPruning.pruneTrackListSelection(validTrackListIDs: validTrackListIDs)

        if let pendingDeleteTrackListId,
           validTrackListIDs.contains(pendingDeleteTrackListId) == false {
            self.pendingDeleteTrackListId = nil
        }
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
}
