//
//  CreateTrackListContainer.swift
//  TrackList
//
//  Контейнер создания нового треклиста.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI
import Foundation

struct CreateTrackListContainer: View {

    // MARK: - Состояние

    /// ViewModel формы уже собрана feature-factory и удерживается на время sheet-flow.
    @StateObject private var viewModel: CreateTrackListViewModel

    // MARK: - Инициализация

    init(viewModel: CreateTrackListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Интерфейс

    var body: some View {
        CreateTrackListSheet(
            name: Binding(
                get: { viewModel.state.name },
                set: { newName in
                    viewModel.handle(.nameChanged(newName))
                }
            ),
            canSubmit: viewModel.state.canSubmit,
            onCreateEmpty: {
                viewModel.handle(.createEmpty)
            },
            onAddTracks: {
                viewModel.handle(.addTracks)
            },
            onCancel: {
                viewModel.handle(.cancel)
            }
        )
    }
}
