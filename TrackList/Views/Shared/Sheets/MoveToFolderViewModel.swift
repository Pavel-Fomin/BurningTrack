//
//  MoveToFolderViewModel.swift
//  TrackList
//
//  Принимает actions и публикует состояние Move To Folder.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Владеет published ScreenState, а commands и lifecycle делегирует feature ActionHandler-у.
@MainActor
final class MoveToFolderViewModel: ObservableObject, MoveToFolderStateReceiving {
    /// Единственный immutable снимок, который читает SwiftUI container.
    @Published private(set) var state: MoveToFolderScreenState

    /// Handler получает typed actions только после завершения factory composition.
    private var actionHandler: MoveToFolderActionHandler?

    init(initialState: MoveToFolderScreenState) {
        state = initialState
    }

    /// Подключает command owner после того, как ViewModel стала Presenter output.
    func configure(actionHandler: MoveToFolderActionHandler) {
        self.actionHandler = actionHandler
    }

    /// Передаёт намерение View в feature flow без production-зависимостей в SwiftUI.
    func send(_ action: MoveToFolderAction) {
        actionHandler?.handle(action)
    }

    /// Принимает готовое presentation-состояние исключительно от Presenter.
    func receive(_ state: MoveToFolderScreenState) {
        self.state = state
    }
}
