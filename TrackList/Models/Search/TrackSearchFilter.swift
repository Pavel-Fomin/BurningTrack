//
//  TrackSearchFilter.swift
//  TrackList
//
//  Модели и вычисление фильтров совпадений поиска треков.
//  Created by Pavel Fomin on 08.07.2026.
//

import Foundation

// Поле, по которому найдено совпадение в результате поиска трека.
enum TrackSearchMatchField: Hashable {
    case tag(EditableTrackField)
    case fileName

    /// Теговые поля берём из единого enum формы редактирования, чтобы не держать отдельную копию списка.
    static var orderedFields: [TrackSearchMatchField] {
        EditableTrackField.tagFields.map(TrackSearchMatchField.tag) + [.fileName]
    }

}

// Чип фильтра поиска: nil в field означает общий чип "Все".
struct TrackSearchFilterChip: Identifiable, Equatable {
    let field: TrackSearchMatchField?
    let count: Int

    /// Стабильный id не зависит от счётчика, чтобы выбор не пересоздавал все чипы.
    var id: String {
        field?.id ?? "all"
    }
}

// Отдельно считает совпадения, чипы и применяет выбранный фильтр к найденным трекам.
struct TrackSearchFilterBuilder {
    /// Возвращает поля, в которых конкретный трек совпал с текущим запросом.
    func matchingFields(
        for result: SearchTrackResult,
        query: String
    ) -> Set<TrackSearchMatchField> {
        let normalizedQuery = Self.normalized(query)
        guard normalizedQuery.isEmpty == false else { return [] }

        return Set(
            TrackSearchMatchField.orderedFields.filter { field in
                matches(
                    values: values(
                        for: field,
                        result: result,
                        query: normalizedQuery
                    ),
                    query: normalizedQuery
                )
            }
        )
    }

    /// Собирает чипы по полной выдаче треков для текущего запроса.
    func chips(
        for results: [SearchTrackResult],
        query: String
    ) -> [TrackSearchFilterChip] {
        let normalizedQuery = Self.normalized(query)
        guard normalizedQuery.isEmpty == false,
              results.isEmpty == false else {
            return []
        }

        let matchesByTrackId = matchingFieldsByTrackId(
            for: results,
            query: normalizedQuery
        )
        let fieldChips: [TrackSearchFilterChip] = TrackSearchMatchField.orderedFields.compactMap { field in
            let count = results.filter { result in
                matchesByTrackId[result.id]?.contains(field) == true
            }.count

            guard count > 0 else { return nil }

            return TrackSearchFilterChip(
                field: field,
                count: count
            )
        }

        return [
            TrackSearchFilterChip(
                field: nil,
                count: results.count
            )
        ] + fieldChips
    }

    /// Оставляет все треки для "Все" или только совпавшие по выбранному полю.
    func filteredResults(
        _ results: [SearchTrackResult],
        query: String,
        selectedField: TrackSearchMatchField?
    ) -> [SearchTrackResult] {
        guard let selectedField else { return results }

        let normalizedQuery = Self.normalized(query)
        guard normalizedQuery.isEmpty == false else { return [] }

        return results.filter { result in
            matchingFields(
                for: result,
                query: normalizedQuery
            ).contains(selectedField)
        }
    }

    /// Проверяет, что выбранное поле всё ещё есть среди чипов нового результата.
    func containsChip(
        field: TrackSearchMatchField?,
        results: [SearchTrackResult],
        query: String
    ) -> Bool {
        chips(for: results, query: query).contains { chip in
            chip.field == field
        }
    }

    /// Считает совпадения один раз для построения всех чипов.
    private func matchingFieldsByTrackId(
        for results: [SearchTrackResult],
        query: String
    ) -> [UUID: Set<TrackSearchMatchField>] {
        results.reduce(into: [UUID: Set<TrackSearchMatchField>]()) { partialResult, result in
            partialResult[result.id] = matchingFields(
                for: result,
                query: query
            )
        }
    }

    /// Возвращает значения конкретного поля без пустых строк.
    private func values(
        for field: TrackSearchMatchField,
        result: SearchTrackResult,
        query: String
    ) -> [String] {
        switch field {
        case .tag(let tagField):
            return tagValues(for: tagField, result: result)

        case .fileName:
            let values = isPathQuery(query)
                ? [result.fileName, result.relativePath]
                : [result.fileName]
            return values.compactMap(Self.nonEmpty)
        }
    }

    /// Маппит реальные редактируемые теги на сохранённые поля результата поиска.
    private func tagValues(
        for field: EditableTrackField,
        result: SearchTrackResult
    ) -> [String] {
        let value: String?

        switch field {
        case .title:
            value = result.title
        case .artist:
            value = result.artist
        case .album:
            value = result.album
        case .genre:
            value = result.genre
        case .year:
            value = result.year.map(String.init)
        case .publisher:
            value = result.label
        case .comment:
            value = result.comment
        }

        return [value].compactMap(Self.nonEmpty)
    }

    /// Совпадение повторяет параметры доменного поиска по строковым значениям.
    private func matches(
        values: [String],
        query: String
    ) -> Bool {
        values.contains { value in
            value.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            ) != nil
        }
    }

    /// Относительный путь относится к файловому чипу только для явных path-запросов.
    private func isPathQuery(_ query: String) -> Bool {
        query.contains("/") || query.contains("\\")
    }

    /// Убирает пробелы по краям, чтобы пустые metadata не создавали чипы.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }

    /// Нормализует запрос тем же образом, что и сервис поиска.
    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension TrackSearchMatchField {
    /// Строковый id сохраняет различие между тегами и файловым полем.
    var id: String {
        switch self {
        case .tag(let field):
            return "tag-\(field)"
        case .fileName:
            return "fileName"
        }
    }
}
