//
//  AppSettings.swift
//  TrackList
//
//  Модель настроек приложения с версией схемы для будущих миграций.
//
//  Created by Pavel Fomin on 12.05.2026.
//

import Foundation


struct AppSettings: Codable, Equatable {

    let schemaVersion: Int
    var visible: VisibleSettings
    var internalSettings: InternalSettings

    // Сохраняет ключ internal в JSON, не используя зарезервированное имя в Swift-модели.
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case visible
        case internalSettings = "internal"
    }

    static let currentSchemaVersion = 1

    // Базовое состояние настроек для первого запуска или восстановления отсутствующего файла.
    static var defaultValue: AppSettings {
        AppSettings(
            schemaVersion: currentSchemaVersion,
            visible: VisibleSettings.defaultValue,
            internalSettings: InternalSettings.defaultValue
        )
    }
}

extension AppSettings {

    // Настройки, которые могут быть доступны пользователю через интерфейс приложения.
    struct VisibleSettings: Codable, Equatable {
        var metadata: MetadataSettings

        // Значения пользовательских настроек по умолчанию.
        static var defaultValue: VisibleSettings {
            VisibleSettings(
                metadata: MetadataSettings.defaultValue
            )
        }
    }

    // Настройки обработки метаданных треков.
    struct MetadataSettings: Codable, Equatable {
        var isTagReadingEnabled: Bool

        // По умолчанию чтение тегов включено, чтобы метаданные подхватывались автоматически.
        static var defaultValue: MetadataSettings {
            MetadataSettings(
                isTagReadingEnabled: true
            )
        }
    }

    // Внутренние настройки приложения, не предназначенные для пользовательского редактирования.
    struct InternalSettings: Codable, Equatable {
        // Пока внутренних параметров нет, поэтому используется пустая структура.
        static var defaultValue: InternalSettings {
            InternalSettings()
        }
    }
}
