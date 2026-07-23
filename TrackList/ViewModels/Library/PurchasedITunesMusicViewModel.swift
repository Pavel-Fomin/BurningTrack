//
//  PurchasedITunesMusicViewModel.swift
//  TrackList
//
//  ViewModel экрана “Куплено в iTunes”.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Foundation

/// Узкий контракт настройки сортировки не раскрывает ViewModel остальные настройки приложения.
@MainActor
protocol PurchasedITunesTrackSortModePersisting: AnyObject {
    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode { get }
    func setPurchasedITunesTrackSortMode(_ mode: PurchasedITunesTrackSortMode) throws
}

extension AppSettingsManager: PurchasedITunesTrackSortModePersisting {
    /// Возвращает восстановленный из SQLite режим runtime-источника iTunes.
    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode {
        settings.internalSettings.purchasedITunesTrackSortMode
    }
}

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
    /// Выбранный режим, восстановленный из SQLite-настроек фонотеки.
    @Published private(set) var sortMode: PurchasedITunesTrackSortMode

    // MARK: - Зависимости

    /// Сервис чтения системной медиатеки iOS.
    private let provider: any PurchasedITunesMusicProviding
    /// Узкий контракт сохранения выбранного режима сортировки.
    private let sortModePersistence: any PurchasedITunesTrackSortModePersisting

    // MARK: - Загруженные данные

    /// Исходные треки хранятся отдельно, чтобы смена сортировки не читала MPMediaItem повторно.
    private var loadedTracks: [PurchasedITunesTrack] = []

    // MARK: - Инициализация

    init(
        provider: any PurchasedITunesMusicProviding = PurchasedITunesMusicProvider(),
        sortModePersistence: (any PurchasedITunesTrackSortModePersisting)? = nil
    ) {
        let resolvedPersistence = sortModePersistence ?? AppSettingsManager.shared

        self.provider = provider
        self.sortModePersistence = resolvedPersistence
        self.sortMode = resolvedPersistence.purchasedITunesTrackSortMode
    }

    // MARK: - Действия

    /// Запрашивает доступ и загружает локальные треки медиатеки.
    func load() async {
        state = .loading
        loadedTracks = []

        let accessState = await provider.requestAccessIfNeeded()
        guard accessState == .authorized else {
            state = .denied
            return
        }

        let tracks = provider.loadTracks()
        loadedTracks = tracks
        rebuildLoadedState()
    }

    /// Применяет новый режим к уже загруженным данным и сохраняет выбор в SQLite.
    func selectSortMode(
        _ mode: PurchasedITunesTrackSortMode
    ) {
        guard sortMode != mode else { return }

        let previousMode = sortMode
        sortMode = mode
        rebuildLoadedState()

        do {
            try sortModePersistence.setPurchasedITunesTrackSortMode(mode)
        } catch {
            // При ошибке сохранения возвращаем UI и данные к последнему подтверждённому режиму.
            sortMode = previousMode
            rebuildLoadedState()
            PersistentLogger.log("Не удалось сохранить сортировку iTunes в SQLite: \(error)")
        }
    }

    // MARK: - Подготовка состояния

    /// Пересобирает готовый плоский список из кэшированного исходного массива.
    private func rebuildLoadedState() {
        guard loadedTracks.isEmpty == false else {
            if case .loading = state {
                state = .empty
            }
            return
        }

        state = .loaded(
            PurchasedITunesTrackSorter.sort(
                loadedTracks,
                mode: sortMode
            )
        )
    }
}
