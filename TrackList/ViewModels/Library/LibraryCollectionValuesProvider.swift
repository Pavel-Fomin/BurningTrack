//
//  LibraryCollectionValuesProvider.swift
//  TrackList
//
//  Provider значений разделов музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

protocol LibraryCollectionValuesProvider {
    /// Возвращает значения выбранного раздела коллекции из сохранённых SQLite metadata.
    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue]
}

final class DefaultLibraryCollectionValuesProvider: LibraryCollectionValuesProvider {
    // MARK: - Dependencies

    /// Фасад локального SQLite-индекса треков и сохранённых metadata.
    private let trackRegistry: TrackRegistry

    // MARK: - Init

    init(trackRegistry: TrackRegistry = .shared) {
        self.trackRegistry = trackRegistry
    }

    // MARK: - LibraryCollectionValuesProvider

    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue] {
        let tracks = await trackRegistry.allTracks().sorted(by: stableTrackOrder)
        let metadataByTrackId = await trackRegistry.cachedMetadata(
            forTrackIds: tracks.map(\.id)
        )
        var buckets: [CollectionBucketKey: ValueBucket] = [:]

        for track in tracks {
            // Значения считаются по тем же локальным строкам, которые потом может открыть список треков.
            guard track.relativePath != nil,
                  let metadata = metadataByTrackId[track.id],
                  let rawValue = category.metadataValue(from: metadata) else {
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

            var bucket = buckets[bucketKey] ?? ValueBucket(rawValue: rawValue)
            bucket.append(
                trackId: track.id,
                metadata: metadata,
                category: category
            )
            buckets[bucketKey] = bucket
        }

        return buckets
            .map { key, bucket in
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
            .sorted { left, right in
                let titleOrder = left.title.localizedStandardCompare(right.title)
                if titleOrder != .orderedSame {
                    return titleOrder == .orderedAscending
                }

                return (left.artist ?? "").localizedStandardCompare(right.artist ?? "") == .orderedAscending
            }
    }

    // MARK: - Private

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
