//
//  ToastManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI
import Combine

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var data: ToastData?
    private var dismissTask: Task<Void, Never>?
    
    // Показывает тост, избегая дубликатов
    func show(_ newToast: ToastData, duration: TimeInterval = 2.0) {
        // Отменяем предыдущий dismiss, если есть
        dismissTask?.cancel()
        
        // Если тот же самый тост — не обновляем
        if data == newToast {
            return
        }
        
        data = newToast
        
        // Планируем скрытие
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
