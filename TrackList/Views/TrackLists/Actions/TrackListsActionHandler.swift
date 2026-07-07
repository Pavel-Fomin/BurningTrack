//
//  TrackListsActionHandler.swift
//  TrackList
//
//  Обрабатывает действия экрана списка треклистов.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

@MainActor
final class TrackListsActionHandler {

    /// ViewModel экрана списка треклистов.
    private let viewModel: TrackListsViewModel

    /// Презентер пользовательских действий списка треклистов.
    private let presenter: any TrackListsPresenting

    init(
        viewModel: TrackListsViewModel,
        presenter: any TrackListsPresenting
    ) {
        self.viewModel = viewModel
        self.presenter = presenter
    }

    func handle(
        _ action: TrackListsAction
    ) {

        switch action {

        case .onAppear:
            viewModel.refresh()

        case .openTrackList(let id):
            viewModel.openTrackList(id: id)

        case .openTrackListFromApp(let id):
            viewModel.openTrackListFromApp(id: id)

        case .createTrackList:
            presenter.presentCreateTrackList()

        case .setSortMode(let mode):
            viewModel.setSortMode(mode)

        case .requestDeleteTrackList(let id):
            viewModel.requestDeleteTrackList(id: id)

        case .confirmDeleteTrackList(let id):
            viewModel.deleteTrackList(id: id)

        case .cancelDeleteTrackList:
            viewModel.cancelDeleteTrackList()

        case .moveTrackList(let source, let destination):
            viewModel.moveTrackList(from: source, to: destination)
        }
    }
}
