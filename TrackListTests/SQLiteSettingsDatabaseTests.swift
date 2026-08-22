//
//  SQLiteSettingsDatabaseTests.swift
//  TrackList
//
//  Проверки SQLite-персистентности настроек приложения.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteSettingsDatabaseTests: SQLiteDatabaseTestCase {
    func testSettingsDatabaseStoreCreatesDefaultSettingsOnlyOnce() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)

        let initialSettings = try store.fetchSettings {
            nil
        }

        XCTAssertEqual(initialSettings, AppSettings.defaultValue)
        XCTAssertEqual(initialSettings.internalSettings.libraryRootDisplayMode, .folders)
        XCTAssertEqual(initialSettings.internalSettings.purchasedITunesTrackSortMode, .titleAsc)

        let reloadedSettings = try store.fetchSettings {
            nil
        }

        XCTAssertEqual(reloadedSettings, initialSettings)
    }

    func testSettingsDatabaseStoreSavesWorkingSettingsToSQLite() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        var settings = try store.fetchSettings {
            nil
        }

        settings.visible.metadata.isTagReadingEnabled = false
        settings.visible.library.isTrackListMembershipVisible = false
        settings.visible.library.isFileFormatVisible = false
        settings.visible.library.isPurchasedITunesSourceVisible = false
        settings.internalSettings.libraryRootDisplayMode = .tracks
        settings.internalSettings.purchasedITunesTrackSortMode = .dateAddedDesc
        settings.internalSettings.trackListsSortMode = .name

        try store.saveSettings(settings)

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertFalse(reloadedSettings.visible.metadata.isTagReadingEnabled)
        XCTAssertFalse(reloadedSettings.visible.library.isTrackListMembershipVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isFileFormatVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
        XCTAssertEqual(reloadedSettings.internalSettings.libraryRootDisplayMode, .tracks)
        XCTAssertEqual(reloadedSettings.internalSettings.purchasedITunesTrackSortMode, .dateAddedDesc)
        XCTAssertEqual(reloadedSettings.internalSettings.trackListsSortMode, .name)

        var foldersSettings = reloadedSettings
        foldersSettings.internalSettings.libraryRootDisplayMode = .folders
        try store.saveSettings(foldersSettings)

        XCTAssertEqual(
            try store.fetchSettings { AppSettings.defaultValue }
            .internalSettings.libraryRootDisplayMode,
            .folders
        )
    }

    func testSettingsDatabaseStorePersistsMiniPlayerPresentationState() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        let initialSettings = try store.fetchSettings {
            nil
        }

        XCTAssertFalse(initialSettings.internalSettings.isMiniPlayerExpanded)

        var expandedSettings = initialSettings
        expandedSettings.internalSettings.isMiniPlayerExpanded = true
        try store.saveSettings(expandedSettings)

        let reloadedExpandedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }
        XCTAssertTrue(reloadedExpandedSettings.internalSettings.isMiniPlayerExpanded)

        var collapsedSettings = reloadedExpandedSettings
        collapsedSettings.internalSettings.isMiniPlayerExpanded = false
        try store.saveSettings(collapsedSettings)

        let reloadedCollapsedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }
        XCTAssertFalse(reloadedCollapsedSettings.internalSettings.isMiniPlayerExpanded)
    }

    func testSQLiteAppSettingsStoreRejectsCorruptedMiniPlayerPresentationState() throws {
        let database = try makeDatabase()
        let settingsStore = try SettingsDatabaseStore(database: database)
        _ = try settingsStore.fetchSettings {
            nil
        }

        let executor = try database.databaseExecutor()
        try executor.write { database in
            // Отключаем проверку ограничения только в тесте, чтобы смоделировать повреждённую базу.
            try database.executeScript(
                """
                PRAGMA ignore_check_constraints = ON;
                UPDATE app_settings SET mini_player_expanded = 2 WHERE id = 1;
                """
            )
        }

        let appSettingsStore = try SQLiteAppSettingsStore(database: database)
        XCTAssertThrowsError(try appSettingsStore.fetch())
    }

    func testSettingsDatabaseStoreFallsBackToFoldersForMissingLibraryRootDisplayMode() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        var settings = try store.fetchSettings {
            nil
        }

        // NULL моделирует строку старой базы без сохранённого режима корня фонотеки.
        settings.visible.library.isPurchasedITunesSourceVisible = false
        try store.saveSettings(settings)

        let executor = try database.databaseExecutor()
        try executor.write { database in
            let statement = try database.prepare(
                "UPDATE library_view_settings SET library_root_display_mode = NULL WHERE id = 1;"
            )
            try statement.execute()
        }

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertEqual(reloadedSettings.internalSettings.libraryRootDisplayMode, .folders)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
    }
}
