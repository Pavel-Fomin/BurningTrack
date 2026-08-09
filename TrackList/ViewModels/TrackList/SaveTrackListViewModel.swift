//
//  SaveTrackListViewModel.swift
//  TrackList
//
//  ViewModel sheet-flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Владеет presentation-состоянием формы и передаёт подтверждённые действия в ActionHandler.
@MainActor
final class SaveTrackListViewModel: ObservableObject {
    /// Готовое presentation-состояние Save TrackList sheet.
    @Published private(set) var state: SaveTrackListState

    /// Собирает presentation-состояние из текста формы и процесса сохранения.
    private let stateBuilder: SaveTrackListStateBuilder
    /// Выполняет сохранение и маршрутизацию flow.
    private let actionHandler: SaveTrackListActionHandler
    /// Не даёт отложенной UI-задаче менять закрытый route.
    private var isSessionActive = true
    /// Удерживает отложенную задачу формы до её завершения.
    private var submissionTask: Task<Void, Never>?

    init(
        initialName: String = generateDefaultTrackListName(),
        stateBuilder: SaveTrackListStateBuilder,
        actionHandler: SaveTrackListActionHandler
    ) {
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.state = stateBuilder.build(
            name: initialName,
            isSubmitting: false
        )
    }

    /// Обрабатывает typed-действия формы без прямого доступа к production-зависимостям.
    func handle(_ action: SaveTrackListAction) {
        switch action {
        case .nameChanged(let name):
            state = stateBuilder.build(
                name: name,
                isSubmitting: state.isSubmitting
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

    /// Блокирует повторное подтверждение до окончания текущей доменной команды.
    private func submit() {
        guard state.canSubmit else { return }

        let submittedName = state.name
        state = stateBuilder.build(
            name: submittedName,
            isSubmitting: true
        )

        submissionTask = Task { [weak self] in
            guard let self else { return }

            _ = actionHandler.submit(name: submittedName)
            guard isSessionActive else { return }
            state = stateBuilder.build(
                name: state.name,
                isSubmitting: false
            )
        }
    }

    /// Закрытый route больше не принимает локальные completion-обновления.
    private func invalidateSession() {
        isSessionActive = false
    }
}
