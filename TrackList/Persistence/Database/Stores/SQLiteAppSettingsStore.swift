//
//  SQLiteAppSettingsStore.swift
//  TrackList
//
//  Доступ к таблице app_settings.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку app_settings.
protocol AppSettingsDatabaseReading {
    func fetch() throws -> AppSettingsDatabaseModel?
}

// Записывает единственную строку app_settings.
protocol AppSettingsDatabaseWriting {
    func insert(_ model: AppSettingsDatabaseModel) throws
    func update(_ model: AppSettingsDatabaseModel) throws
    func upsert(_ model: AppSettingsDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице app_settings.
final class SQLiteAppSettingsStore: AppSettingsDatabaseReading, AppSettingsDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> AppSettingsDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> AppSettingsDatabaseModel {
        let schemeRawValue = try row.requiredString(at: 2)
        guard let preferredColorScheme = DatabasePreferredColorScheme(rawValue: schemeRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.AppSettings.preferredColorScheme, value: schemeRawValue)
        }

        let miniPlayerExpandedValue = try row.requiredInt(at: 6)
        guard miniPlayerExpandedValue == 0 || miniPlayerExpandedValue == 1 else {
            throw DatabaseError.invalidColumnValue(
                column: DatabaseSchema.AppSettings.miniPlayerExpanded,
                value: String(miniPlayerExpandedValue)
            )
        }

        return AppSettingsDatabaseModel(
            id: try row.requiredInt(at: 0),
            schemaVersion: try row.requiredInt(at: 1),
            preferredColorScheme: preferredColorScheme,
            accentColorName: row.string(at: 3),
            lastOpenedTab: row.string(at: 4),
            isTagReadingEnabled: try row.requiredBool(at: 5),
            miniPlayerExpanded: miniPlayerExpandedValue == 1,
            createdAt: try row.requiredDate(at: 7),
            updatedAt: try row.requiredDate(at: 8)
        )
    }

    private static func bindInsert(
        _ model: AppSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу app_settings.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.schemaVersion, at: 2)
        try statement.bind(model.preferredColorScheme.rawValue, at: 3)
        try statement.bind(model.accentColorName, at: 4)
        try statement.bind(model.lastOpenedTab, at: 5)
        try statement.bind(model.isTagReadingEnabled, at: 6)
        try statement.bind(model.miniPlayerExpanded, at: 7)
        try statement.bind(model.createdAt, at: 8)
        try statement.bind(model.updatedAt, at: 9)
    }

    private static func bindUpdate(
        _ model: AppSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.schemaVersion, at: 1)
        try statement.bind(model.preferredColorScheme.rawValue, at: 2)
        try statement.bind(model.accentColorName, at: 3)
        try statement.bind(model.lastOpenedTab, at: 4)
        try statement.bind(model.isTagReadingEnabled, at: 5)
        try statement.bind(model.miniPlayerExpanded, at: 6)
        try statement.bind(model.createdAt, at: 7)
        try statement.bind(model.updatedAt, at: 8)
        try statement.bind(model.id, at: 9)
    }
}

// Фасад рабочих настроек скрывает SQLite-модели от слоя менеджеров.
final class SettingsDatabaseStore {
    private let executor: DatabaseExecutor
    private let appSettingsStore: any AppSettingsDatabaseReading & AppSettingsDatabaseWriting
    private let libraryViewSettingsStore: any LibraryViewSettingsDatabaseReading & LibraryViewSettingsDatabaseWriting
    private let playerSettingsStore: any PlayerSettingsDatabaseReading & PlayerSettingsDatabaseWriting

    init(
        executor: DatabaseExecutor,
        appSettingsStore: any AppSettingsDatabaseReading & AppSettingsDatabaseWriting,
        libraryViewSettingsStore: any LibraryViewSettingsDatabaseReading & LibraryViewSettingsDatabaseWriting,
        playerSettingsStore: any PlayerSettingsDatabaseReading & PlayerSettingsDatabaseWriting
    ) {
        self.executor = executor
        self.appSettingsStore = appSettingsStore
        self.libraryViewSettingsStore = libraryViewSettingsStore
        self.playerSettingsStore = playerSettingsStore
    }

    convenience init(database: AppDatabase = .shared) throws {
        let executor = try database.databaseExecutor()
        self.init(
            executor: executor,
            appSettingsStore: SQLiteAppSettingsStore(executor: executor),
            libraryViewSettingsStore: SQLiteLibraryViewSettingsStore(executor: executor),
            playerSettingsStore: SQLitePlayerSettingsStore(executor: executor)
        )
    }

    /// Загружает рабочие настройки из SQLite и создаёт строки по умолчанию при первом запуске.
    func fetchSettings(
        initialSettingsProvider: () -> AppSettings?
    ) throws -> AppSettings {
        let appModel = try appSettingsStore.fetch()
        let libraryModel = try libraryViewSettingsStore.fetch()
        let playerModel = try playerSettingsStore.fetch()
        let shouldUseInitialSettings = appModel == nil && libraryModel == nil
        let sourceSettings = shouldUseInitialSettings
            ? (initialSettingsProvider() ?? .defaultValue)
            : .defaultValue
        let now = Date()

        let resolvedAppModel = appModel ?? Self.makeAppSettingsModel(
            from: sourceSettings,
            createdAt: now,
            updatedAt: now
        )
        let resolvedLibraryModel = libraryModel ?? Self.makeLibraryViewSettingsModel(
            from: sourceSettings,
            updatedAt: now
        )
        let resolvedPlayerModel = playerModel ?? Self.makePlayerSettingsModel(updatedAt: now)

        if appModel == nil || libraryModel == nil || playerModel == nil {
            try executor.transaction { _ in
                try appSettingsStore.upsert(resolvedAppModel)
                try libraryViewSettingsStore.upsert(resolvedLibraryModel)
                try playerSettingsStore.upsert(resolvedPlayerModel)
            }
        }

        return Self.makeAppSettings(
            appModel: resolvedAppModel,
            libraryModel: resolvedLibraryModel
        )
    }

    /// Сохраняет рабочие настройки приложения, не раскрывая модели базы выше Store.
    func saveSettings(_ settings: AppSettings) throws {
        let now = Date()
        var appModel = try appSettingsStore.fetch() ?? Self.makeAppSettingsModel(
            from: settings,
            createdAt: now,
            updatedAt: now
        )
        var libraryModel = try libraryViewSettingsStore.fetch() ?? Self.makeLibraryViewSettingsModel(
            from: settings,
            updatedAt: now
        )
        let playerModel = try playerSettingsStore.fetch() ?? Self.makePlayerSettingsModel(updatedAt: now)

        // Обновляем только рабочие поля текущей бизнес-модели AppSettings.
        appModel.schemaVersion = settings.schemaVersion
        appModel.isTagReadingEnabled = settings.visible.metadata.isTagReadingEnabled
        appModel.miniPlayerExpanded = settings.internalSettings.isMiniPlayerExpanded
        appModel.updatedAt = now

        libraryModel.showTrackListBadges = settings.visible.library.isTrackListMembershipVisible
        libraryModel.showFileFormat = settings.visible.library.isFileFormatVisible
        libraryModel.showPurchasedITunesSource = settings.visible.library.isPurchasedITunesSourceVisible
        libraryModel.libraryRootDisplayMode = settings.internalSettings.libraryRootDisplayMode.rawValue
        libraryModel.sortMode = settings.internalSettings.libraryTrackSortMode.rawValue
        libraryModel.purchasedITunesSortMode = settings.internalSettings.purchasedITunesTrackSortMode.rawValue
        libraryModel.trackListsSortMode = settings.internalSettings.trackListsSortMode?.rawValue
        libraryModel.updatedAt = now

        try executor.transaction { _ in
            try appSettingsStore.upsert(appModel)
            try libraryViewSettingsStore.upsert(libraryModel)
            try playerSettingsStore.upsert(playerModel)
        }
    }

    private static func makeAppSettings(
        appModel: AppSettingsDatabaseModel,
        libraryModel: LibraryViewSettingsDatabaseModel
    ) -> AppSettings {
        AppSettings(
            schemaVersion: appModel.schemaVersion,
            visible: AppSettings.VisibleSettings(
                metadata: AppSettings.MetadataSettings(
                    isTagReadingEnabled: appModel.isTagReadingEnabled
                ),
                library: AppSettings.LibrarySettings(
                    isTrackListMembershipVisible: libraryModel.showTrackListBadges,
                    isFileFormatVisible: libraryModel.showFileFormat,
                    isPurchasedITunesSourceVisible: libraryModel.showPurchasedITunesSource
                )
            ),
            internalSettings: AppSettings.InternalSettings(
                libraryTrackSortMode: LibraryTrackSortMode(rawValue: libraryModel.sortMode) ?? .fileDateDesc,
                purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode(
                    rawValue: libraryModel.purchasedITunesSortMode
                ) ?? .titleAsc,
                trackListsSortMode: libraryModel.trackListsSortMode.flatMap(TrackListsSortMode.init(rawValue:)),
                libraryRootDisplayMode: LibraryRootDisplayMode(
                    rawValue: libraryModel.libraryRootDisplayMode ?? ""
                ) ?? .folders,
                isMiniPlayerExpanded: appModel.miniPlayerExpanded
            )
        )
    }

    private static func makeAppSettingsModel(
        from settings: AppSettings,
        createdAt: Date,
        updatedAt: Date
    ) -> AppSettingsDatabaseModel {
        AppSettingsDatabaseModel(
            id: 1,
            schemaVersion: settings.schemaVersion,
            preferredColorScheme: .system,
            accentColorName: nil,
            lastOpenedTab: nil,
            isTagReadingEnabled: settings.visible.metadata.isTagReadingEnabled,
            miniPlayerExpanded: settings.internalSettings.isMiniPlayerExpanded,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func makeLibraryViewSettingsModel(
        from settings: AppSettings,
        updatedAt: Date
    ) -> LibraryViewSettingsDatabaseModel {
        LibraryViewSettingsDatabaseModel(
            id: 1,
            sortMode: settings.internalSettings.libraryTrackSortMode.rawValue,
            purchasedITunesSortMode: settings.internalSettings.purchasedITunesTrackSortMode.rawValue,
            trackListsSortMode: settings.internalSettings.trackListsSortMode?.rawValue,
            groupMode: "date",
            showTrackListBadges: settings.visible.library.isTrackListMembershipVisible,
            showUnavailableTracks: true,
            showFileFormat: settings.visible.library.isFileFormatVisible,
            showPurchasedITunesSource: settings.visible.library.isPurchasedITunesSourceVisible,
            libraryRootDisplayMode: settings.internalSettings.libraryRootDisplayMode.rawValue,
            lastOpenedFolderId: nil,
            updatedAt: updatedAt
        )
    }

    private static func makePlayerSettingsModel(updatedAt: Date) -> PlayerSettingsDatabaseModel {
        PlayerSettingsDatabaseModel(
            id: 1,
            autoPlayNext: true,
            restoreLastPosition: true,
            showMiniPlayer: true,
            backgroundPlaybackEnabled: true,
            updatedAt: updatedAt
        )
    }
}
