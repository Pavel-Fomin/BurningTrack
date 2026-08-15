//
//  MoveToFolderPresenter.swift
//  TrackList
//
//  Собирает готовое состояние Move To Folder.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Принимает готовый снимок feature-state без знания domain-зависимостей.
@MainActor
protocol MoveToFolderStateReceiving: AnyObject {
    /// Публикует presentation-state для SwiftUI container.
    func receive(_ state: MoveToFolderScreenState)
}

/// Преобразует mutable feature-state в единственный immutable ScreenState.
@MainActor
final class MoveToFolderPresenter {
    /// Слабый output исключает цикл ActionHandler → Presenter → ViewModel.
    private weak var output: (any MoveToFolderStateReceiving)?

    init(output: (any MoveToFolderStateReceiving)? = nil) {
        self.output = output
    }

    /// Подключает владельца published ScreenState после завершения его инициализации.
    func configure(output: any MoveToFolderStateReceiving) {
        self.output = output
    }

    /// Публикует готовое состояние только через единую presentation-точку.
    func present(
        navigationTitle: String,
        folderSnapshot: MoveToFolderFolderSnapshot,
        selectedFolderID: UUID?,
        currentFolderID: UUID?,
        isPerformingOperation: Bool
    ) {
        output?.receive(
            makeState(
                navigationTitle: navigationTitle,
                folderSnapshot: folderSnapshot,
                selectedFolderID: selectedFolderID,
                currentFolderID: currentFolderID,
                isPerformingOperation: isPerformingOperation
            )
        )
    }

    /// Собирает initial state и позволяет проверять presentation-правила изолированно.
    func makeState(
        navigationTitle: String,
        folderSnapshot: MoveToFolderFolderSnapshot,
        selectedFolderID: UUID?,
        currentFolderID: UUID?,
        isPerformingOperation: Bool
    ) -> MoveToFolderScreenState {
        MoveToFolderScreenState(
            navigationTitle: navigationTitle,
            folderSnapshot: folderSnapshot,
            selectedFolderID: selectedFolderID,
            currentFolderID: currentFolderID,
            isPerformingOperation: isPerformingOperation,
            canSubmit: selectedFolderID != nil
                && selectedFolderID != currentFolderID
                && !isPerformingOperation
        )
    }
}
