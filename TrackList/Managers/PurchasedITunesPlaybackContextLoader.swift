//
//  PurchasedITunesPlaybackContextLoader.swift
//  TrackList
//
//  Загружает полный отсортированный контекст воспроизведения для купленных треков iTunes.
//
//  Created by Pavel Fomin on 01.08.2026.
//

import Foundation

/// Узкий контракт настройки сортировки не раскрывает загрузчикам и ViewModel остальные настройки приложения.
@MainActor
protocol PurchasedITunesTrackSortModePersisting: AnyObject {
    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode { get }
    func setPurchasedITunesTrackSortMode(_ mode: PurchasedITunesTrackSortMode) throws
}

extension AppSettingsManager: PurchasedITunesTrackSortModePersisting {
    /// Возвращает восстановленный из SQLite режим сортировки runtime-источника iTunes.
    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode {
        settings.internalSettings.purchasedITunesTrackSortMode
    }
}

/// Описывает итог загрузки iTunes-контекста без смешения пустой медиатеки и временной недоступности источника.
enum PurchasedITunesPlaybackContextLoadResult: Equatable {
    /// Медиатека успешно прочитана; массив может быть пустым.
    case loaded([PurchasedITunesPlayableTrack])
    /// Доступ ещё не определён, поэтому отсутствие трека нельзя считать окончательным.
    case temporarilyUnavailable
    /// Пользователь или система запретили доступ к системной медиатеке.
    case accessDenied
}

/// Загружает полный порядок воспроизведения Purchased iTunes вне PlayerViewModel и экранной ViewModel.
@MainActor
protocol PurchasedITunesPlaybackContextLoading: AnyObject {
    /// Возвращает отсортированный актуальный список или точную причину, по которой он пока недоступен.
    func loadPlaybackContext() async -> PurchasedITunesPlaybackContextLoadResult
}

/// Рабочий загрузчик повторно использует источник MediaPlayer и единственный сортировщик экрана «Куплено в iTunes».
@MainActor
final class PurchasedITunesPlaybackContextLoader: PurchasedITunesPlaybackContextLoading {

    /// Источник актуальных треков системной медиатеки.
    private let provider: any PurchasedITunesMusicProviding
    /// Тестовая подмена режима исключает создание SQLite-настроек при изолированной проверке загрузчика.
    private let sortModePersistence: (any PurchasedITunesTrackSortModePersisting)?

    /// Создаёт загрузчик без экранного состояния; рабочая настройка выбирается только при фактическом чтении iTunes.
    init(
        provider: any PurchasedITunesMusicProviding = PurchasedITunesMusicProvider(),
        sortModePersistence: (any PurchasedITunesTrackSortModePersisting)? = nil
    ) {
        self.provider = provider
        self.sortModePersistence = sortModePersistence
    }

    /// Строит контекст из актуальной системной медиатеки и сохранённого порядка без BookmarkResolver и локальной фонотеки.
    func loadPlaybackContext() async -> PurchasedITunesPlaybackContextLoadResult {
        switch provider.accessState() {
        case .authorized:
            let sortMode = sortModePersistence?.purchasedITunesTrackSortMode ??
                AppSettingsManager.shared.purchasedITunesTrackSortMode
            let tracks = PurchasedITunesTrackSorter.sort(
                provider.loadTracks(),
                mode: sortMode
            ).map(PurchasedITunesPlayableTrack.init(track:))
            return .loaded(tracks)

        case .notDetermined:
            return .temporarilyUnavailable

        case .denied:
            return .accessDenied
        }
    }
}
