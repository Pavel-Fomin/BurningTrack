//
//  TrackDetailManager.swift
//  TrackList
//
//  Управляет показом экрана "О треке" (TrackDetailSheet)
//  Вызывается глобально из любого раздела приложения
//
//  Created by Pavel Fomin on 13.10.2025.
//

import Foundation

@MainActor
final class TrackDetailManager: ObservableObject {
    static let shared = TrackDetailManager()   /// Синглтон
    @Published var track: (any TrackDisplayable)? = nil

    private init() {}

    /// Открывает экран "О треке" для переданного трека
    func open(track: any TrackDisplayable) {
        self.track = track
    }

    /// Закрывает экран
    func close() {
        self.track = nil
    }
}
