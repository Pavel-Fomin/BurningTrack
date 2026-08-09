//
//  AddToTrackListViewModel.swift
//  TrackList
//
//  ViewModel feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Владеет выбором destination-треклиста и готовым presentation-состоянием формы.
@MainActor
final class AddToTrackListViewModel: ObservableObject {
    /// Готовое presentation-состояние sheet.
    @Published private(set) var state: AddToTrackListState

    /// Нормализованный неизменяемый запрос текущего flow.
    private let request: AddToTrackListRequest
    /// Доступные треклисты, подготовленные factory через явную зависимость.
    private let trackLists: [TrackListMeta]
    /// Собирает presentation-state из доменных метаданных и выбора.
    private let stateBuilder: AddToTrackListStateBuilder
    /// Выполняет доменную операцию и маршрутизацию flow.
    private let actionHandler: AddToTrackListActionHandler
    /// Показывает ошибку первоначальной синхронной загрузки списка.
    private let toastPresenter: any ToastPresenting
    /// Не даёт completion закрытого route повторно менять его presentation state.
    private var isSessionActive = true
    /// Удерживает асинхронную операцию до её естественного завершения.
    private var submissionTask: Task<Void, Never>?

    init(
        request: AddToTrackListRequest,
        trackListsResult: Result<[TrackListMeta], Error>,
        stateBuilder: AddToTrackListStateBuilder,
        actionHandler: AddToTrackListActionHandler,
        toastPresenter: any ToastPresenting
    ) {
        self.request = request
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.toastPresenter = toastPresenter

        let resolvedTrackLists: [TrackListMeta]
        let loadError: Error?

        switch trackListsResult {
        case .success(let trackLists):
            resolvedTrackLists = trackLists
            loadError = nil
        case .failure(let error):
            resolvedTrackLists = []
            loadError = error
        }
        self.trackLists = resolvedTrackLists

        self.state = stateBuilder.build(
            trackLists: resolvedTrackLists,
            selectedTrackListId: nil,
            excludedTrackListId: request.excludedTrackListId,
            isLoading: false,
            isSubmitting: false
        )

        if let loadError {
            presentLoadError(loadError)
        }
    }

    /// Обрабатывает только typed-действия UI формы.
    func handle(_ action: AddToTrackListAction) {
        switch action {
        case .trackListSelected(let trackListId):
            toggleSelection(trackListId)

        case .submit:
            submit()

        case .cancel:
            invalidateSession()
            actionHandler.cancel()

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Переключает destination только среди доступных строк state.
    private func toggleSelection(_ trackListId: UUID) {
        guard state.items.contains(where: { $0.id == trackListId && $0.isAvailable }) else {
            return
        }

        let selectedTrackListId = state.selectedTrackListId == trackListId
            ? nil
            : trackListId
        state = stateBuilder.build(
            trackLists: trackLists,
            selectedTrackListId: selectedTrackListId,
            excludedTrackListId: request.excludedTrackListId,
            isLoading: false,
            isSubmitting: false
        )
    }

    /// Блокирует повторное подтверждение до завершения текущей команды.
    private func submit() {
        guard state.canSubmit,
              let trackListId = state.selectedTrackListId,
              let destination = trackLists.first(where: { $0.id == trackListId })
        else {
            return
        }

        state = stateBuilder.build(
            trackLists: trackLists,
            selectedTrackListId: trackListId,
            excludedTrackListId: request.excludedTrackListId,
            isLoading: false,
            isSubmitting: true
        )

        submissionTask = Task { [weak self] in
            guard let self else { return }

            _ = await actionHandler.submit(
                request: request,
                destination: destination
            )
            guard isSessionActive else { return }
            state = stateBuilder.build(
                trackLists: trackLists,
                selectedTrackListId: trackListId,
                excludedTrackListId: request.excludedTrackListId,
                isLoading: false,
                isSubmitting: false
            )
        }
    }

    /// Помечает UI-сеанс завершённым, не отменяя уже начатую доменную операцию.
    private func invalidateSession() {
        isSessionActive = false
    }

    /// Сохраняет текущее сообщение ошибки загрузки списка треклистов.
    private func presentLoadError(_ error: Error) {
        if let appError = error as? AppError {
            toastPresenter.handle(appError)
            return
        }

        toastPresenter.handle(AppError.trackListLoadFailed)
    }
}
