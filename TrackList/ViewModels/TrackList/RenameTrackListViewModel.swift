//
//  RenameTrackListViewModel.swift
//  TrackList
//
//  ViewModel формы переименования треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Владеет состоянием формы и передаёт подтверждённые действия в ActionHandler.
@MainActor
final class RenameTrackListViewModel: ObservableObject {

    // MARK: - State

    /// Готовое presentation-состояние формы переименования.
    @Published private(set) var state: RenameTrackListState

    // MARK: - Dependencies

    /// Идентификатор треклиста, переданный sheet route.
    private let trackListId: UUID
    /// Исходное имя используется для проверки отсутствия изменений после нормализации.
    private let currentName: String
    /// Собирает presentation-состояние формы.
    private let stateBuilder: RenameTrackListStateBuilder
    /// Выполняет доменную команду и закрытие flow.
    private let actionHandler: RenameTrackListActionHandler
    /// Не даёт отложенной UI-задаче менять закрытый route.
    private var isSessionActive = true
    /// Удерживает отложенную задачу формы до её завершения.
    private var submissionTask: Task<Void, Never>?

    // MARK: - Init

    init(
        trackListId: UUID,
        currentName: String,
        stateBuilder: RenameTrackListStateBuilder,
        actionHandler: RenameTrackListActionHandler
    ) {
        self.trackListId = trackListId
        self.currentName = currentName
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.state = stateBuilder.build(
            name: currentName,
            currentName: currentName,
            isSubmitting: false
        )
    }

    // MARK: - Actions

    /// Обновляет состояние ввода или передаёт подтверждённое действие обработчику.
    func handle(_ action: RenameTrackListAction) {
        switch action {
        case .nameChanged(let name):
            state = stateBuilder.build(
                name: name,
                currentName: currentName,
                isSubmitting: false
            )

        case .submit:
            submit()

        case .cancel:
            invalidateSession()
            actionHandler.cancel()

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Блокирует повторное подтверждение до завершения текущей доменной команды.
    private func submit() {
        guard state.canSubmit else { return }

        let name = state.name
        state = stateBuilder.build(
            name: name,
            currentName: currentName,
            isSubmitting: true
        )

        submissionTask = Task { [weak self] in
            guard let self else { return }

            _ = actionHandler.rename(
                trackListId: trackListId,
                newName: name
            )
            guard isSessionActive else { return }
            state = stateBuilder.build(
                name: name,
                currentName: currentName,
                isSubmitting: false
            )
        }
    }

    /// Закрытый route больше не принимает локальные completion-обновления.
    private func invalidateSession() {
        isSessionActive = false
    }
}
