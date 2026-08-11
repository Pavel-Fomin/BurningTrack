//
//  PurchasedITunesMusicViewModel.swift
//  TrackList
//
//  ViewModel экрана “Куплено в iTunes”.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Combine
import Foundation

@MainActor
final class PurchasedITunesMusicViewModel: ObservableObject {

    // MARK: - Выходные данные

    /// Готовое состояние экрана публикуется после преобразования Presenter-ом.
    @Published private(set) var screenState: PurchasedITunesScreenState

    // MARK: - Зависимости

    /// Сервис чтения системной медиатеки iOS.
    private let provider: any PurchasedITunesMusicProviding
    /// Узкий контракт сохранения выбранного режима сортировки.
    private let sortModePersistence: any PurchasedITunesTrackSortModePersisting
    /// Подтверждённое состояние «Избранного» участвует только в подготовке строк Presenter-ом.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Узкий playback-снимок нужен Presenter-у для готовых флагов текущей строки.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Чистый presentation-слой не выполняет запросы доступа и не управляет UIKit.
    private let presenter: PurchasedITunesPresenter

    // MARK: - Загруженные данные

    /// Исходные треки хранятся отдельно, чтобы смена сортировки не читала MPMediaItem повторно.
    private var loadedTracks: [PurchasedITunesTrack] = []
    /// Текущее состояние процесса не раскрывается View и становится ScreenState только через Presenter.
    private var content: PurchasedITunesMusicContent = .idle
    /// Выбранный режим сортировки хранится рядом с исходными данными до успешного сохранения в SQLite.
    private var sortMode: PurchasedITunesTrackSortMode
    /// Подписки feature собираются рядом с данными, а не в SwiftUI View.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    init(
        provider: any PurchasedITunesMusicProviding,
        sortModePersistence: any PurchasedITunesTrackSortModePersisting,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        playbackStateProvider: any PlaybackStateProviding,
        presenter: PurchasedITunesPresenter
    ) {
        self.provider = provider
        self.sortModePersistence = sortModePersistence
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.playbackStateProvider = playbackStateProvider
        self.presenter = presenter
        self.sortMode = sortModePersistence.purchasedITunesTrackSortMode
        self.screenState = presenter.present(
            content: .idle,
            sortMode: sortMode,
            favoriteTrackIds: favoriteTrackIdsProvider.favoriteTrackIds,
            playbackState: playbackStateProvider.playbackState
        )

        observePresentationDependencies()
    }

    // MARK: - Действия

    /// Запрашивает доступ и загружает локальные треки медиатеки.
    func load() async {
        content = .loading
        loadedTracks = []
        presentCurrentState()

        let accessState = await provider.requestAccessIfNeeded()
        guard accessState == .authorized else {
            content = .denied
            presentCurrentState()
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
            if case .loading = content {
                content = .empty
            }
            presentCurrentState()
            return
        }

        content = .loaded(
            PurchasedITunesTrackSorter.sort(
                loadedTracks,
                mode: sortMode
            )
        )
        presentCurrentState()
    }

    /// Пересобирает снимок при изменении данных, сортировки, favorite или playback runtime-состояния.
    private func presentCurrentState() {
        screenState = presenter.present(
            content: content,
            sortMode: sortMode,
            favoriteTrackIds: favoriteTrackIdsProvider.favoriteTrackIds,
            playbackState: playbackStateProvider.playbackState
        )
    }

    /// Подписки на узкие runtime-контракты не позволяют SwiftUI View самостоятельно собирать строки.
    private func observePresentationDependencies() {
        favoriteTrackIdsProvider.favoriteTrackIdsPublisher
            .sink { [weak self] _ in
                self?.presentCurrentState()
            }
            .store(in: &cancellables)

        playbackStateProvider.playbackStatePublisher
            .sink { [weak self] _ in
                self?.presentCurrentState()
            }
            .store(in: &cancellables)
    }
}
