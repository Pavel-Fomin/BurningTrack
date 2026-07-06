//
//  AppSettings.swift
//  TrackList
//
//  Модель настроек приложения с версией схемы для будущих миграций.
//
//  Created by Pavel Fomin on 12.05.2026.
//

import Foundation


struct AppSettings: Equatable {

    let schemaVersion: Int
    var visible: VisibleSettings
    var internalSettings: InternalSettings

    static let currentSchemaVersion = 1

    // Базовое состояние настроек для первого запуска или восстановления отсутствующих строк SQLite.
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
    struct VisibleSettings: Equatable {
        var metadata: MetadataSettings
        var library: LibrarySettings

        // Значения пользовательских настроек по умолчанию.
        static var defaultValue: VisibleSettings {
            VisibleSettings(
                metadata: MetadataSettings.defaultValue,
                library: LibrarySettings.defaultValue
            )
        }

        init(metadata: MetadataSettings, library: LibrarySettings) {
            self.metadata = metadata
            self.library = library
        }
    }

    // Настройки обработки метаданных треков.
    struct MetadataSettings: Equatable {
        var isTagReadingEnabled: Bool

        // По умолчанию чтение тегов включено, чтобы метаданные подхватывались автоматически.
        static var defaultValue: MetadataSettings {
            MetadataSettings(
                isTagReadingEnabled: true
            )
        }
    }

    // Настройки отображения фонотеки.
    struct LibrarySettings: Equatable {
        var isTrackListMembershipVisible: Bool
        var isFileFormatVisible: Bool
        var isPurchasedITunesSourceVisible: Bool

        init(
            isTrackListMembershipVisible: Bool,
            isFileFormatVisible: Bool,
            isPurchasedITunesSourceVisible: Bool
        ) {
            self.isTrackListMembershipVisible = isTrackListMembershipVisible
            self.isFileFormatVisible = isFileFormatVisible
            self.isPurchasedITunesSourceVisible = isPurchasedITunesSourceVisible
        }

        // По умолчанию показываем связь трека с треклистами, формат файла и источник iTunes.
        static var defaultValue: LibrarySettings {
            LibrarySettings(
                isTrackListMembershipVisible: true,
                isFileFormatVisible: true,
                isPurchasedITunesSourceVisible: true
            )
        }
    }

    // Внутренние настройки приложения, не предназначенные для пользовательского редактирования.
    struct InternalSettings: Equatable {
        var trackListsSortMode: TrackListsSortMode?
        var libraryFoldersSortMode: LibraryFoldersSortMode?

        init(
            trackListsSortMode: TrackListsSortMode?,
            libraryFoldersSortMode: LibraryFoldersSortMode?
        ) {
            self.trackListsSortMode = trackListsSortMode
            self.libraryFoldersSortMode = libraryFoldersSortMode
        }

        // По умолчанию треклисты и папки фонотеки используют сохранённый фактический порядок без выбранной сортировки.
        static var defaultValue: InternalSettings {
            InternalSettings(
                trackListsSortMode: nil,
                libraryFoldersSortMode: nil
            )
        }
    }
}
