//
//  LibraryCollectionValuesProvider.swift
//  TrackList
//
//  Provider значений разделов музыкальной коллекции.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import Foundation

protocol LibraryCollectionValuesProvider {
    /// Возвращает значения выбранного раздела коллекции из сохранённых SQLite metadata.
    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue]

    /// Возвращает значения нескольких разделов из одного общего снимка SQLite metadata.
    func values(
        for categories: [LibraryCollectionCategory]
    ) async -> [LibraryCollectionCategory: [LibraryCollectionValue]]
}

extension LibraryCollectionValuesProvider {
    /// Даёт совместимую реализацию пакетной загрузки для provider-ов,
    /// которые пока умеют читать только один раздел за раз.
    func values(
        for categories: [LibraryCollectionCategory]
    ) async -> [LibraryCollectionCategory: [LibraryCollectionValue]] {
        var valuesByCategory: [LibraryCollectionCategory: [LibraryCollectionValue]] = [:]

        for category in categories {
            valuesByCategory[category] = await values(for: category)
        }

        return valuesByCategory
    }
}

/// Provider готовых строк корня режима "Треки".
protocol LibraryCollectionRootItemsProvider {
    /// Возвращает строки корня с количеством фактических destination-строк.
    func rootItemsState() async -> [LibraryCollectionRootItemState]
}

final class DefaultLibraryCollectionValuesProvider: LibraryCollectionValuesProvider, LibraryCollectionRootItemsProvider {
    // MARK: - Dependencies

    /// Фасад локального SQLite-индекса треков и сохранённых metadata.
    private let trackRegistry: TrackRegistry

    // MARK: - Init

    init(trackRegistry: TrackRegistry = .shared) {
        self.trackRegistry = trackRegistry
    }

    // MARK: - LibraryCollectionValuesProvider

    /// Возвращает значения одного раздела из общего builder-а коллекции.
    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue] {
        let snapshot = await makeSnapshot(for: [category])
        return snapshot.valuesByCategory[category] ?? []
    }

    /// Возвращает значения всех переданных разделов одним чтением треков и metadata.
    func values(
        for categories: [LibraryCollectionCategory]
    ) async -> [LibraryCollectionCategory: [LibraryCollectionValue]] {
        await makeSnapshot(for: categories).valuesByCategory
    }

    // MARK: - LibraryCollectionRootItemsProvider

    /// Возвращает корневые строки, используя количество построенных значений категорий.
    func rootItemsState() async -> [LibraryCollectionRootItemState] {
        let snapshot = await makeSnapshot(for: LibraryCollectionCategory.allCases)

        return LibraryCollectionRootItem.rootItems.map { item in
            let count: Int

            switch item {
            case .allTracks:
                count = snapshot.allTracksCount
            case .category(let category):
                count = snapshot.valuesByCategory[category]?.count ?? 0
            }

            return LibraryCollectionRootItemState(
                item: item,
                count: count
            )
        }
    }

    // MARK: - Private

    /// Собирает один снимок треков и metadata для всех запрошенных разделов.
    private func makeSnapshot(
        for categories: [LibraryCollectionCategory]
    ) async -> CollectionValuesSnapshot {
        let uniqueCategories = categories.reduce(into: [LibraryCollectionCategory]()) { result, category in
            guard result.contains(category) == false else { return }
            result.append(category)
        }
        let tracks = await trackRegistry.allTracks().sorted(by: stableTrackOrder)
        let metadataByTrackId = await trackRegistry.cachedMetadata(
            forTrackIds: tracks.map(\.id)
        )
        var bucketsByCategory: [LibraryCollectionCategory: [CollectionBucketKey: ValueBucket]] =
            Dictionary(uniqueKeysWithValues: uniqueCategories.map { ($0, [:]) })

        for track in tracks {
            guard track.relativePath != nil,
                  let metadata = metadataByTrackId[track.id] else {
                continue
            }

            for category in uniqueCategories {
                guard let rawValue = category.metadataValue(from: metadata) else {
                    continue
                }

                let artistKey = category == .albums
                    ? category.albumArtistKey(from: metadata)
                    : nil
                let bucketKey = CollectionBucketKey(
                    category: category,
                    rawValue: rawValue,
                    artistKey: artistKey
                )
                guard bucketKey.valueKey.isEmpty == false else { continue }

                var buckets = bucketsByCategory[category] ?? [:]
                var bucket = buckets[bucketKey] ?? ValueBucket(rawValue: rawValue)
                bucket.append(
                    trackId: track.id,
                    metadata: metadata,
                    category: category
                )
                buckets[bucketKey] = bucket
                bucketsByCategory[category] = buckets
            }
        }

        let valuesByCategory = Dictionary(uniqueKeysWithValues: uniqueCategories.map { category in
            let values = bucketsByCategory[category, default: [:]].map { key, bucket in
                LibraryCollectionValue(
                    id: "\(category.rawValue):\(key.idComponent)",
                    category: category,
                    title: bucket.rawValue,
                    rawValue: bucket.rawValue,
                    tracksCount: bucket.tracksCount,
                    artist: bucket.artist,
                    year: bucket.year,
                    representativeTrackId: bucket.representativeTrackId,
                    trackIds: bucket.trackIds
                )
            }

            return (category, values)
        })

        return CollectionValuesSnapshot(
            allTracksCount: tracks.reduce(into: 0) { count, track in
                if track.relativePath != nil {
                    count += 1
                }
            },
            valuesByCategory: valuesByCategory
        )
    }

    /// Задаёт стабильный порядок обхода треков, чтобы representative и trackIds не зависели от порядка SQLite при равных датах.
    private func stableTrackOrder(
        _ left: TrackRegistry.TrackEntry,
        _ right: TrackRegistry.TrackEntry
    ) -> Bool {
        if left.importedAt != right.importedAt {
            return left.importedAt > right.importedAt
        }

        return left.id.uuidString.localizedStandardCompare(right.id.uuidString) == .orderedAscending
    }

    private struct CollectionBucketKey: Hashable {
        /// Нормализованное основное значение раздела: альбом, артист, жанр, лейбл или год.
        let valueKey: String
        /// Нормализованная часть исполнителя альбома; у остальных разделов всегда nil.
        let artistKey: String?

        init(
            category: LibraryCollectionCategory,
            rawValue: String,
            artistKey: String?
        ) {
            self.valueKey = category.normalizedMetadataKey(for: rawValue)
            self.artistKey = category == .albums
                ? artistKey.map { category.normalizedMetadataKey(for: $0) }
                : nil
        }

        /// Делает строковый id без неоднозначности между названием альбома и ключом исполнителя.
        var idComponent: String {
            let artistComponent = artistKey.map { "\($0.count):\($0)" } ?? "none"
            return "\(valueKey.count):\(valueKey)|artist:\(artistComponent)"
        }
    }

    /// Результат одного чтения SQLite, используемый и корнем, и экраном значений.
    private struct CollectionValuesSnapshot {
        /// Количество локальных строк, которые открывает пункт "Треки".
        let allTracksCount: Int
        /// Готовые значения всех запрошенных категорий по их текущим правилам группировки.
        let valuesByCategory: [LibraryCollectionCategory: [LibraryCollectionValue]]
    }

    private struct ValueBucket {
        /// Первое отображаемое значение для группы одинаковых metadata.
        let rawValue: String
        /// Количество треков в группе.
        var tracksCount: Int = 0
        /// Первый подходящий исполнитель альбома из сохранённых metadata.
        var artist: String?
        /// Первый подходящий год альбома из сохранённых metadata.
        var year: Int?
        /// Первый трек группы, по которому UI может лениво получить обложку.
        var representativeTrackId: UUID?
        /// Все trackId группы для проверки текущего воспроизведения внутри альбома.
        var trackIds: [UUID] = []

        /// Добавляет трек в группу и сохраняет album-данные только для раздела альбомов.
        mutating func append(
            trackId: UUID,
            metadata: TrackCachedMetadata,
            category: LibraryCollectionCategory
        ) {
            tracksCount += 1

            guard category == .albums else { return }

            trackIds.append(trackId)

            // Первый трек группы становится представителем для точечной загрузки обложки.
            if representativeTrackId == nil {
                representativeTrackId = trackId
            }

            // Для нижней строки предпочитаем album artist, если он уже сохранён в SQLite.
            if artist == nil {
                artist = nonEmptyString(metadata.albumArtist) ?? nonEmptyString(metadata.artist)
            }

            // Год берём из первого трека альбома, где он есть в сохранённых metadata.
            if year == nil {
                year = metadata.year
            }
        }

        /// Убирает пустые строки из дополнительных metadata альбома.
        private func nonEmptyString(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  value.isEmpty == false else {
                return nil
            }

            return value
        }
    }
}
