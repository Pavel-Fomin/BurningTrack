//
//  ErrorHandling.swift
//  TrackList
//
//  Логирование ошибок, Алерты, Логи
//
//  Created by Pavel Fomin on 20.05.2025.
//

import Foundation
import SwiftUI

final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showAlert: Bool = false

    private init() {}

    func handle(_ error: AppError, showAlert: Bool = false) {
        log(error)
        
        if showAlert {
            DispatchQueue.main.async {
                self.currentError = error
                self.showAlert = true
            }
        }
    }

    private func log(_ error: AppError) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("❌ [\(timestamp)] Ошибка: \(error.localizedDescription)")
    }
}
