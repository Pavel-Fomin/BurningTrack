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
    
    func show(
        message: String,
        title: String? = nil,
        artist: String? = nil,
        artwork: UIImage? = nil,
        duration: TimeInterval = 5.0
    ) {
        let toastData = ToastData(
            title: title,
            artist: artist,
            artwork: artwork,
            message: message
        )
        
        print("🔥 Показать тост: \(message)")
        self.data = toastData
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            print("🧹 Очистить тост")
            if self.data?.id == toastData.id {
                self.data = nil
            }
        }
    }
}
