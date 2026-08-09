//
//  TrackDetailSheet.swift
//  TrackList
//
//  Отображает готовые состояния просмотра и редактирования Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Собирает leaf Views только из TrackDetailScreenState и typed UI-действий.
struct TrackDetailSheet: View {
    /// Полное состояние экрана, подготовленное ViewModel.
    let state: TrackDetailScreenState
    /// Единственный обратный канал пользовательских намерений.
    let send: (TrackDetailAction) -> Void

    var body: some View {
        Group {
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                switch state.mode {
                case .view:
                    TrackDetailReadOnlyView(state: state)

                case .edit:
                    TrackDetailEditForm(state: state, send: send)
                }
            }
        }
    }
}
