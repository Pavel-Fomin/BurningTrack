//
//  AppSettingsManager.swift
//  TrackList
//
//  Управляет загрузкой и сохранением рабочих настроек приложения через SQLite.
//
//  Created by Pavel Fomin on 12.05.2026.
//

import Foundation

// Управляет загрузкой и сохранением рабочих настроек приложения через SettingsDatabaseStore.
@MainActor
final class AppSettingsManager: ObservableObject, SettingsManaging, PlaybackModePersisting {
    static let shared = AppSettingsManager()

    @Published private(set) var settings: AppSettings

    // Предоставляет Settings-flow поток изменений без раскрытия projected value свойства.
    var settingsPublisher: Published<AppSettings>.Publisher {
        $settings
    }

    private let settingsStore: SettingsDatabaseStore
    /// Отдельный доступ к полям режима через каноничный SQLitePlayerSettingsStore.
    private let playbackModeStore: SQLitePlayerSettingsStore

    private init() {
        let resolvedSettingsStore: SettingsDatabaseStore
        do {
            resolvedSettingsStore = try SettingsDatabaseStore()
        } catch {
            preconditionFailure("Не удалось подготовить SQLite-хранилище настроек: \(error.localizedDescription)")
        }
        settingsStore = resolvedSettingsStore

        do {
            playbackModeStore = try SQLitePlayerSettingsStore()
        } catch {
            preconditionFailure("Не удалось подготовить SQLite-хранилище режима плеера: \(error.localizedDescription)")
        }

        settings = AppSettings.defaultValue
        load()
    }

    func load() {
        do {
            settings = try settingsStore.fetchSettings { nil }
        } catch {
            // При ошибке SQLite восстанавливаем дефолты через основной Store без резервного файлового источника.
            settings = AppSettings.defaultValue
            save()
        }
    }

    func save() {
        do {
            try settingsStore.saveSettings(settings)
        } catch {
            print("Не удалось сохранить настройки приложения: \(error.localizedDescription)")
        }
    }

    /// Синхронно загружает режим до создания playback-контекста.
    func loadPlaybackMode() -> PlaybackMode {
        do {
            guard let model = try playbackModeStore.fetchPlaybackMode() else {
                return .defaultValue
            }

            return PlaybackMode(
                isShuffleEnabled: model.shuffleEnabled,
                repeatMode: PlaybackRepeatMode(rawValue: model.repeatMode.rawValue) ?? .off
            ).normalized
        } catch {
            // Любое повреждение строки режима не должно блокировать запуск playback-системы.
            PersistentLogger.log("⚠️ Не удалось загрузить режим воспроизведения из SQLite: \(error)")
            return .defaultValue
        }
    }

    /// Синхронно сохраняет только режим воспроизведения через player_settings.
    func savePlaybackMode(_ mode: PlaybackMode) {
        let normalizedMode = mode.normalized
        let model = PlayerPlaybackModeDatabaseModel(
            repeatMode: DatabaseRepeatMode(rawValue: normalizedMode.repeatMode.rawValue) ?? .off,
            shuffleEnabled: normalizedMode.isShuffleEnabled,
            updatedAt: Date()
        )

        do {
            try playbackModeStore.upsertPlaybackMode(model)
        } catch {
            PersistentLogger.log("⚠️ Не удалось сохранить режим воспроизведения в SQLite: \(error)")
        }
    }

    func setTagReadingEnabled(_ value: Bool) {
        guard settings.visible.metadata.isTagReadingEnabled != value else { return }

        settings.visible.metadata.isTagReadingEnabled = value
        save()

        TrackMetadataCacheManager.shared.invalidateAll()
        TrackRuntimeStore.shared.removeAllSnapshots()
        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
    }

    func setTrackListMembershipVisible(_ value: Bool) {
        guard settings.visible.library.isTrackListMembershipVisible != value else { return }

        settings.visible.library.isTrackListMembershipVisible = value
        save()

        // Видимость бейджа относится только к presentation state строк фонотеки и поиска.
    }

    func setFileFormatVisible(_ value: Bool) {
        guard settings.visible.library.isFileFormatVisible != value else { return }

        settings.visible.library.isFileFormatVisible = value
        save()

        // Формат файла не меняет metadata трека и не требует пересборки runtime snapshot-ов плеера.
    }

    func setPurchasedITunesSourceVisible(_ value: Bool) {
        guard settings.visible.library.isPurchasedITunesSourceVisible != value else { return }

        settings.visible.library.isPurchasedITunesSourceVisible = value
        save()

        // Видимость источника обновляется корневым экраном фонотеки через settingsPublisher.
    }

    /// Сохраняет состояние раскрытия мини-плеера среди общих настроек интерфейса.
    func setMiniPlayerExpanded(_ value: Bool) {
        guard settings.internalSettings.isMiniPlayerExpanded != value else { return }

        settings.internalSettings.isMiniPlayerExpanded = value
        save()
    }

    /// Сохраняет последний выбранный режим отображения корня фонотеки.
    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {
        guard settings.internalSettings.libraryRootDisplayMode != mode else { return }

        let previousMode = settings.internalSettings.libraryRootDisplayMode
        settings.internalSettings.libraryRootDisplayMode = mode

        do {
            try settingsStore.saveSettings(settings)
        } catch {
            settings.internalSettings.libraryRootDisplayMode = previousMode
            throw error
        }

        // Режим корня меняет только компоновку фонотеки и не влияет на metadata или artwork.
        // Общее событие запускало пересборку snapshot-ов всей очереди плеера при каждом переключении.
    }

    /// Сохраняет выбранную сортировку треков внутри папки фонотеки.
    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {
        guard settings.internalSettings.libraryTrackSortMode != mode else { return }

        let previousMode = settings.internalSettings.libraryTrackSortMode
        settings.internalSettings.libraryTrackSortMode = mode

        do {
            try settingsStore.saveSettings(settings)
        } catch {
            settings.internalSettings.libraryTrackSortMode = previousMode
            throw error
        }

        // Сортировка уже применяется инициировавшей LibraryTracksViewModel и не касается плеера.
    }

    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {
        guard settings.internalSettings.trackListsSortMode != mode else { return }

        let previousMode = settings.internalSettings.trackListsSortMode
        settings.internalSettings.trackListsSortMode = mode

        do {
            try settingsStore.saveSettings(settings)
        } catch {
            settings.internalSettings.trackListsSortMode = previousMode
            throw error
        }

        // Сортировка уже применяется инициировавшей TrackListsViewModel и не касается плеера.
    }

}
