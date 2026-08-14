//
//  ToastManager.swift
//  TrackList
//
//  Централизованный менеджер жизненного цикла Toast'ов.
//  Принимает готовые данные presentation-слоя и управляет их показом.
//
//  Created by Pavel Fomin on 08.07.2025
//

import SwiftUI

@MainActor
final class ToastManager: ObservableObject {

    // MARK: - Единый экземпляр

    static let shared = ToastManager()

    // MARK: - Публичное состояние

    @Published private(set) var data: ToastData?

    // MARK: - Внутреннее состояние

    private var dismissTask: Task<Void, Never>?

    // MARK: - Публичный API

    func handle(_ event: ToastEvent, duration: TimeInterval = 2.0) {

        let toastData = ToastPresentation.makeData(from: event)

        show(toastData, duration: duration)
    }

    func handle(_ error: AppError) {
        handle(error.toastEvent)
    }

    // MARK: - Внутренняя логика

    private func show(_ newToast: ToastData, duration: TimeInterval) {

        if data == newToast {
            return
        }

        dismissTask?.cancel()

        data = newToast

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if self.data == newToast {
                self.data = nil
            }
        }
    }

}

// MARK: - Подключение к ToastPresenting

extension ToastManager: ToastPresenting {}
