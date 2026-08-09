//
//  SaveTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана сохранения очереди плеера в треклист.
//
//  Роль контейнера:
//  - удерживает готовую ViewModel Save TrackList flow
//  - передаёт presentation-state и typed actions в UI
//
//  ВАЖНО:
//  - НЕ содержит визуальной разметки формы
//  - НЕ рисует TextField напрямую
//  - НЕ используется повторно как UI-компонент
//  - является аналогом UIViewController в UIKit
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct SaveTrackListContainer: View {

    /// Готовая ViewModel формы, созданная feature factory.
    @StateObject private var viewModel: SaveTrackListViewModel

    init(viewModel: SaveTrackListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - UI

    var body: some View {
        SaveTrackListSheet(
            state: viewModel.state,
            onAction: viewModel.handle
        )
        .onDisappear {
            viewModel.handle(.sheetDisappeared)
        }
    }
}
