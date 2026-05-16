//
//  AppSettingsManager.swift
//  TrackList
//
//  Управляет загрузкой и сохранением настроек приложения в Documents/settings.json.
//
//  Created by Pavel Fomin on 12.05.2026.
//

import Foundation

// Управляет загрузкой и сохранением настроек приложения в Documents/settings.json.
@MainActor
final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published private(set) var settings: AppSettings

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        // Используем ту же директорию Documents, что и остальные JSON-реестры приложения.
        let appDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        fileURL = appDirectory.appendingPathComponent("settings.json")

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder = jsonEncoder
        decoder = JSONDecoder()

        settings = AppSettings.defaultValue
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(AppSettings.self, from: data)
            settings = decoded
        } catch {
            // При первом запуске или поврежденном файле восстанавливаем настройки по умолчанию.
            settings = AppSettings.defaultValue
            save()
        }
    }

    func save() {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
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
}
