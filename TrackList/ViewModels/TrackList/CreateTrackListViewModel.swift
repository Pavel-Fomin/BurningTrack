//
//  CreateTrackListViewModel.swift
//  TrackList
//
//  ViewModel формы создания нового треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Владеет состоянием формы и передаёт подтверждённые действия в ActionHandler.
@MainActor
final class CreateTrackListViewModel: ObservableObject {

    // MARK: - State

    /// Готовое presentation-состояние формы.
    @Published private(set) var state: CreateTrackListState

    // MARK: - Dependencies

    /// Собирает состояние формы из текущего имени.
    private let stateBuilder: CreateTrackListStateBuilder
    /// Выполняет доменные команды и маршрутизацию flow.
    private let actionHandler: CreateTrackListActionHandler

    // MARK: - Init

    init(
        initialName: String = generateDefaultTrackListName(),
        stateBuilder: CreateTrackListStateBuilder,
        actionHandler: CreateTrackListActionHandler
    ) {
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.state = stateBuilder.build(name: initialName)
    }

    // MARK: - Actions

    /// Обновляет состояние формы или передаёт подтверждённое действие обработчику.
    func handle(_ action: CreateTrackListAction) {
        if case let .nameChanged(name) = action {
            state = stateBuilder.build(name: name)
            return
        }

        actionHandler.handle(action, name: state.name)
    }
}
