//
//  TrackListsOrderingDatabaseStore.swift
//  TrackList
//
//  Атомарное сохранение порядка master-списка и выбранной сортировки.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Сохраняет два представления одной пользовательской команды в общей SQLite-транзакции.
final class TrackListsOrderingDatabaseStore: TrackListsOrderingPersisting {

    /// Общий executor гарантирует одну транзакцию для разных таблиц приложения.
    private let executor: DatabaseExecutor
    /// Фасад валидации и записи полного отображаемого порядка треклистов.
    private let trackListsStore: TrackListDatabaseStore
    /// Хранилище единственной строки настроек отображения фонотеки.
    private let libraryViewSettingsStore: any LibraryViewSettingsDatabaseReading & LibraryViewSettingsDatabaseWriting

    init(
        executor: DatabaseExecutor,
        trackListsStore: TrackListDatabaseStore,
        libraryViewSettingsStore: any LibraryViewSettingsDatabaseReading & LibraryViewSettingsDatabaseWriting
    ) {
        self.executor = executor
        self.trackListsStore = trackListsStore
        self.libraryViewSettingsStore = libraryViewSettingsStore
    }

    convenience init(database: AppDatabase = .shared) throws {
        let executor = try database.databaseExecutor()
        self.init(
            executor: executor,
            trackListsStore: TrackListDatabaseStore(executor: executor),
            libraryViewSettingsStore: SQLiteLibraryViewSettingsStore(executor: executor)
        )
    }

    /// Не допускает частичной записи: порядок и sort mode меняются вместе либо оба откатываются.
    func persist(
        sortMode: TrackListsSortMode?,
        orderedTrackListIDs: [UUID]
    ) throws {
        do {
            try executor.transaction { _ in
                try trackListsStore.updateDisplayedTrackListsOrder(orderedTrackListIDs)

                guard var settings = try libraryViewSettingsStore.fetch() else {
                    throw AppError.trackListSaveFailed
                }

                settings.trackListsSortMode = sortMode?.rawValue
                settings.updatedAt = Date()
                try libraryViewSettingsStore.upsert(settings)
            }
        } catch let appError as AppError {
            throw appError
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            throw AppError.trackListSaveFailed
        }
    }
}
