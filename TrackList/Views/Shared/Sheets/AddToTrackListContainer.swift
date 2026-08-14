//
//  AddToTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана добавления трека или выбранных треков в треклист.
//
//  Контейнер удерживает готовую ViewModel feature-flow.
//
//  ВАЖНО:
//  - контейнер не содержит UI-разметки списка
//  - контейнер не создаёт production-зависимости
//  - вся визуальная логика вынесена в AddToTrackListSheet
//  - sheet не знает о командах и навигации
//
//  Архитектурный паттерн:
//  NavigationBarHost (UIKit) + чистый SwiftUI sheet
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI

struct AddToTrackListContainer: View {

    /// Готовая ViewModel, созданная feature factory.
    @StateObject private var viewModel: AddToTrackListViewModel

    init(viewModel: AddToTrackListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Интерфейс

    var body: some View {
        AddToTrackListSheet(
            state: viewModel.state,
            onAction: viewModel.handle
        )
        .onDisappear {
            viewModel.handle(.sheetDisappeared)
        }
    }
}
