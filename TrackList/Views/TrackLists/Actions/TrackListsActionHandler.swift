//
//  TrackListsActionHandler.swift
//  TrackList
//
//  Координирует пользовательские действия master-flow списка треклистов.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation
import SwiftUI

@MainActor
final class TrackListsActionHandler {

    /// ViewModel владеет только опубликованным состоянием master-feature.
    private let viewModel: TrackListsViewModel
    /// Выполняет удаление и публикует invalidation master-списка.
    private let trackListsManager: any TrackListsManaging
    /// Синхронизирует in-memory settings после успешной общей SQLite-транзакции.
    private let settingsManager: any SettingsManaging
    /// Атомарно сохраняет физический порядок и выбранную сортировку.
    private let orderingStore: any TrackListsOrderingPersisting
    /// Показывает ошибки user-команд master-flow.
    private let toastPresenter: any ToastPresenting
    /// Презентер пользовательских действий списка треклистов.
    private let presenter: any TrackListsPresenting
    /// Даёт только одноразовый внешний route без доступа к остальным маршрутам приложения.
    private let externalOpenRequests: any TrackListsExternalOpenRequestManaging

    init(
        viewModel: TrackListsViewModel,
        trackListsManager: any TrackListsManaging,
        settingsManager: any SettingsManaging,
        orderingStore: any TrackListsOrderingPersisting,
        toastPresenter: any ToastPresenting,
        presenter: any TrackListsPresenting,
        externalOpenRequests: any TrackListsExternalOpenRequestManaging
    ) {
        self.viewModel = viewModel
        self.trackListsManager = trackListsManager
        self.settingsManager = settingsManager
        self.orderingStore = orderingStore
        self.toastPresenter = toastPresenter
        self.presenter = presenter
        self.externalOpenRequests = externalOpenRequests
    }

    /// Обрабатывает пользовательское действие master-flow.
    func handle(
        _ action: TrackListsAction
    ) {
        switch action {
        case .onAppear:
            // Оба корневых контейнера используют один master-flow без повторной начальной загрузки.
            viewModel.loadTrackListsIfNeeded()

        case .openTrackList(let id):
            openTrackList(id: id)

        case .openTrackListFromApp(let id):
            openTrackListFromApp(id: id)

        case .createTrackList:
            presenter.presentCreateTrackList()

        case .setSortMode(let mode):
            setSortMode(mode)

        case .requestDeleteTrackList(let id):
            requestDeleteTrackList(id: id)

        case .confirmDeleteTrackList(let id):
            confirmDeleteTrackList(id: id)

        case .cancelDeleteTrackList:
            viewModel.cancelDeleteTrackList()

        case .moveTrackList(let source, let destination):
            moveTrackList(from: source, to: destination)
        }
    }

    /// Потребляет один внешний route; requestId не позволит старому запросу очистить более новый.
    func handlePendingExternalOpenRequest() {
        guard let request = externalOpenRequests.pendingTrackListOpenRequest else {
            return
        }

        if openTrackListFromApp(id: request.trackListId) {
            externalOpenRequests.clearTrackListOpenRequest(requestId: request.requestId)
        }
    }

    // MARK: - Навигация

    /// Открывает существующий треклист из актуального master-снимка.
    private func openTrackList(id: UUID) {
        guard viewModel.containsTrackList(id: id) else {
            toastPresenter.handle(AppError.trackListNotFound)
            return
        }

        viewModel.appendNavigationPath(id: id)
    }

    /// Обновляет отсутствующий в снимке внешний route и затем заменяет текущий detail.
    @discardableResult
    private func openTrackListFromApp(id: UUID) -> Bool {
        if viewModel.containsTrackList(id: id) == false,
           viewModel.reloadTrackLists() == false {
            return false
        }

        guard viewModel.containsTrackList(id: id) else {
            toastPresenter.handle(AppError.trackListNotFound)
            // Не существующий в согласованном снимке route считается обработанным и не должен повторяться.
            return true
        }

        viewModel.replaceNavigationPath(with: id)
        return true
    }

    // MARK: - Сортировка и изменение порядка

    /// Сохраняет выбранный режим и его физический порядок как одну пользовательскую команду.
    private func setSortMode(_ mode: TrackListsSortMode) {
        let updatedTrackLists = mode.applying(to: viewModel.trackLists)

        persistOrdering(
            sortMode: mode,
            orderedTrackLists: updatedTrackLists
        )
    }

    /// Сохраняет новый ручной порядок regular-треклистов и отменяет активную сортировку.
    private func moveTrackList(
        from source: IndexSet,
        to destination: Int
    ) {
        let trackLists = viewModel.trackLists
        let favoritesCount = trackLists.filter { $0.kind == .favorites }.count
        guard source.isEmpty == false,
              source.allSatisfy({ trackLists.indices.contains($0) }),
              source.allSatisfy({ trackLists[$0].kind.canReorder }),
              destination >= favoritesCount,
              destination <= trackLists.count
        else {
            toastPresenter.handle(AppError.trackListReorderNotAllowed)
            return
        }

        let favorites = trackLists.filter { $0.kind == .favorites }
        var regularTrackLists = trackLists.filter { $0.kind == .regular }
        let regularSource = IndexSet(source.map { $0 - favoritesCount })
        let regularDestination = destination - favoritesCount
        regularTrackLists.move(fromOffsets: regularSource, toOffset: regularDestination)

        persistOrdering(
            sortMode: nil,
            orderedTrackLists: favorites + regularTrackLists
        )
    }

    /// Публикует изменение состояния только после успешной общей SQLite-транзакции.
    private func persistOrdering(
        sortMode: TrackListsSortMode?,
        orderedTrackLists: [TrackList]
    ) {
        do {
            try orderingStore.persist(
                sortMode: sortMode,
                orderedTrackListIDs: orderedTrackLists.map(\.id)
            )

            // Сначала меняем in-memory mode, чтобы синхронный invalidation reload применил уже сохранённую сортировку.
            settingsManager.applyPersistedTrackListsSortMode(sortMode)
            viewModel.applyPersistedOrdering(
                orderedTrackLists,
                sortMode: sortMode
            )
            trackListsManager.publishTrackListsDidChange()
        } catch let appError as AppError {
            toastPresenter.handle(appError)
        } catch {
            toastPresenter.handle(AppError.trackListSaveFailed)
        }
    }

    // MARK: - Удаление

    /// Валидирует команду удаления до публикации presentation state подтверждения.
    private func requestDeleteTrackList(id: UUID) {
        guard let trackList = viewModel.trackList(for: id) else {
            toastPresenter.handle(AppError.trackListNotFound)
            return
        }
        guard trackList.kind.canDelete else {
            toastPresenter.handle(AppError.trackListDeletionNotAllowed)
            return
        }

        viewModel.requestDeleteTrackList(id: id)
    }

    /// Выполняет подтверждённое удаление; manager публикует единственный invalidation reload.
    private func confirmDeleteTrackList(id: UUID) {
        guard viewModel.isDeleteRequested(for: id) else {
            return
        }

        do {
            try trackListsManager.deleteTrackList(id: id)
            viewModel.cancelDeleteTrackList()
        } catch let appError as AppError {
            toastPresenter.handle(appError)
        } catch {
            toastPresenter.handle(AppError.trackListSaveFailed)
        }
    }
}
