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
final class AppSettingsManager: ObservableObject, SettingsManaging {
    static let shared = AppSettingsManager()

    @Published private(set) var settings: AppSettings

    // Предоставляет Settings-flow поток изменений без раскрытия projected value свойства.
    var settingsPublisher: Published<AppSettings>.Publisher {
        $settings
    }

    private let settingsStore: SettingsDatabaseStore

    private init() {
        let resolvedSettingsStore: SettingsDatabaseStore
        do {
            resolvedSettingsStore = try SettingsDatabaseStore()
        } catch {
            preconditionFailure("Не удалось подготовить SQLite-хранилище настроек: \(error.localizedDescription)")
        }
        settingsStore = resolvedSettingsStore

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

        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
    }

    func setFileFormatVisible(_ value: Bool) {
        guard settings.visible.library.isFileFormatVisible != value else { return }

        settings.visible.library.isFileFormatVisible = value
        save()

        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
    }

    func setPurchasedITunesSourceVisible(_ value: Bool) {
        guard settings.visible.library.isPurchasedITunesSourceVisible != value else { return }

        settings.visible.library.isPurchasedITunesSourceVisible = value
        save()

        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
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

        NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
    }
}
