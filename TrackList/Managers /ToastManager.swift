//
//  ToastManager.swift
//  TrackList
//
//  Менеджер отображения временных уведомлений на экране
//  Поддерживает автоматическое скрытие и защиту от дублирующихся сообщений
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI
import Combine

@MainActor
final class ToastManager: ObservableObject {
    
    /// Синглтон
    static let shared = ToastManager()
    
    /// Текущие данные тоста (если nil — ничего не показывается)
    @Published var data: ToastData?
    
    /// Активная задача на автоматическое скрытие
    private var dismissTask: Task<Void, Never>?
    
    /// Показывает тост с заданной длительностью
    /// - Parameters:
    ///   - newToast: Данные для отображения
    ///   - duration: Время показа (по умолчанию 2 сек)
    func show(_ newToast: ToastData, duration: TimeInterval = 2.0) {
        
        // Отменяем предыдущее скрытие, если оно ещё выполняется
        dismissTask?.cancel()
        
        // Не показываем повторно один и тот же тост
        if data == newToast {
            return
        }
        
        // Устанавливаем новые данные
        data = newToast
        
        // Запускаем задачу на авто-скрытие
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                if self.data == newToast {
                    self.data = nil
                }
            }
        }
    }
}
