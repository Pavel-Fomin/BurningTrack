//
//  TrackListsLoadFailurePresenting.swift
//  TrackList
//
//  Контракт показа ошибок автоматической загрузки master-flow.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Отделяет реактивную загрузку состояния от конкретного механизма пользовательского сообщения.
@MainActor
protocol TrackListsLoadFailurePresenting {

    /// Показывает ошибку, из-за которой нельзя опубликовать согласованный master-снимок.
    func presentTrackListsLoadFailure(_ error: AppError)
}

extension ToastManager: TrackListsLoadFailurePresenting {

    func presentTrackListsLoadFailure(_ error: AppError) {
        handle(error)
    }
}
