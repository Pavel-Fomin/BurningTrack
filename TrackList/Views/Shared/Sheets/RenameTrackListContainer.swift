//
//  RenameTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана переименования треклиста.
//
//  Роль контейнера:
//  - удерживает готовую ViewModel rename sheet-flow
//  - передаёт presentation-state и typed actions в UI
//
//  Архитектурные принципы:
//  - контейнер не содержит визуальной разметки формы
//  - контейнер не рисует TextField напрямую
//  - контейнер является аналогом UIViewController в UIKit
//  - RenameTrackListSheet — чистый UI-компонент без логики
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct RenameTrackListContainer: View {

    /// Готовая ViewModel формы, созданная feature factory.
    @StateObject private var viewModel: RenameTrackListViewModel

    init(viewModel: RenameTrackListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Интерфейс

    var body: some View {
        RenameTrackListSheet(
            state: viewModel.state,
            onAction: viewModel.handle
        )
        .onDisappear {
            viewModel.handle(.sheetDisappeared)
        }
    }
}
