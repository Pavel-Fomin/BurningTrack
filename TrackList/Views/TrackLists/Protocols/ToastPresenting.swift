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

    /// Показывает пользовательское событие с заданной длительностью.
    func handle(_ event: ToastEvent, duration: TimeInterval)

    /// Показывает ошибку пользовательского уровня.
    func handle(_ error: AppError)
}
