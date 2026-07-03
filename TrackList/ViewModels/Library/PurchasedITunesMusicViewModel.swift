//
//  PurchasedITunesMusicViewModel.swift
//  TrackList
//
//  ViewModel экрана “Куплено в iTunes”.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Foundation

@MainActor
final class PurchasedITunesMusicViewModel: ObservableObject {

    enum State: Equatable {
        /// Экран создан, но чтение медиатеки ещё не запускалось.
        case idle
        /// Идёт запрос доступа или чтение системной медиатеки.
        case loading
        /// Пользователь или система запретили доступ к медиатеке.
        case denied
        /// Доступ есть, но подходящих локальных треков не найдено.
        case empty
        /// Найдены локальные треки, доступные через assetURL.
        case loaded([PurchasedITunesTrack])
    }

    // MARK: - Выходные данные

    /// Текущее состояние экрана для SwiftUI.
    @Published private(set) var state: State = .idle

    // MARK: - Зависимости

    /// Сервис чтения системной медиатеки iOS.
    private let provider: PurchasedITunesMusicProvider

    // MARK: - Инициализация

    init(
        provider: PurchasedITunesMusicProvider = PurchasedITunesMusicProvider()
    ) {
        self.provider = provider
    }

    // MARK: - Действия

    /// Запрашивает доступ и загружает локальные треки медиатеки.
    func load() async {
        state = .loading

        let accessState = await provider.requestAccessIfNeeded()
        guard accessState == .authorized else {
            state = .denied
            return
        }

        let tracks = provider.loadTracks()
        if tracks.isEmpty {
            state = .empty
        } else {
            state = .loaded(tracks)
        }
    }
}
