//
//  LibraryFolderViewModel.swift
//  TrackList
//
//  ViewModel для папки фонотеки
//
//  Created by Pavel Fomin on 08.08.2025.
//

import Foundation
import SwiftUI

@MainActor
final class LibraryFolderViewModel: ObservableObject {
    // MARK: - Output

    @Published private(set) var screenState: LibraryFolderScreenState

    // MARK: - Dependencies

    private let actionHandler: LibraryFolderActionHandler

    // MARK: - Init

    init(
        folder: LibraryFolder,
        stateBuilder: LibraryFolderStateBuilder,
        actionHandler: LibraryFolderActionHandler
    ) {
        self.screenState = stateBuilder.build(folder: folder)
        self.actionHandler = actionHandler
    }

    // MARK: - Actions

    func handle(_ action: LibraryFolderAction) {
        actionHandler.handle(action)
    }
}
