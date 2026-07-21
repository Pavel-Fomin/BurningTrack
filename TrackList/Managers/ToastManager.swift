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

    // MARK: - Singleton

    static let shared = ToastManager()

    // MARK: - Public state

    @Published private(set) var data: ToastData?   /// Текущий тост (nil — ничего не отображается)

    // MARK: - Private

    private var dismissTask: Task<Void, Never>?

    // MARK: - Public API

    /// Основной вход для показа тостов из ViewModel
    func handle(_ event: ToastEvent, duration: TimeInterval = 2.0) {

        let toastData = ToastPresentation.makeData(from: event)

        show(toastData, duration: duration)
    }

    /// Показывает Toast на основе ошибки приложения.
    /// Использует централизованный маппинг AppError -> ToastEvent.
    func handle(_ error: AppError) {
        handle(error.toastEvent)
    }

    // MARK: - Internal logic

    private func show(_ newToast: ToastData, duration: TimeInterval) {

        // Защита от дублей
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

// MARK: - ToastPresenting

extension ToastManager: ToastPresenting {}
