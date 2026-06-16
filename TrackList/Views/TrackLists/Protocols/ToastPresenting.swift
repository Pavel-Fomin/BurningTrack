//
//  ToastPresenting.swift
//  TrackList
//
//  Контракт показа пользовательских сообщений.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

@MainActor
protocol ToastPresenting {

    /// Показывает ошибку пользовательского уровня.
    func handle(_ error: AppError)
}
