//
//  SearchPresenter.swift
//  TrackList
//
//  Presenter состояния поиска.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation
import UIKit

// Настройки отображения трека поиска синхронизированы с поведением строк фонотеки.
struct SearchTrackDisplaySettings {
    let shouldShowTags: Bool
    let shouldShowTrackListMembership: Bool
    let shouldShowFileFormat: Bool
}

// Собирает UI-состояние из запроса и результатов доменного сервиса.
struct SearchPresenter {
    /// Считает совпавшие поля и чипы фильтрации для треков.
    private let trackSearchFilterBuilder = TrackSearchFilterBuilder()

    /// Состояние до ввода запроса.
    func empty(
        query: String = "",
        selectedSortMode: SearchSortMode = .titleAsc
    ) -> SearchScreenState {
        let availableSortModeGroups = SearchSortMode.availableModeGroups(for: nil)

        return SearchScreenState(
            query: query,
            folders: [],
            trackLists: [],
            tracks: [],
            trackFilterChips: [],
            selectedTrackFilterField: nil,
            selectedSortMode: selectedSortMode,
            availableSortModes: availableSortModeGroups.flatMap(\.modes),
            availableSortModeGroups: availableSortModeGroups,
            contentState: .emptyQuery
        )
    }

    /// Состояние активного поиска по непустому запросу.
    func loading(
        query: String,
        selectedSortMode: SearchSortMode
    ) -> SearchScreenState {
        let availableSortModeGroups = SearchSortMode.availableModeGroups(for: nil)

        return SearchScreenState(
            query: query,
            folders: [],
            trackLists: [],
            tracks: [],
            trackFilterChips: [],
            selectedTrackFilterField: nil,
            selectedSortMode: selectedSortMode,
            availableSortModes: availableSortModeGroups.flatMap(\.modes),
            availableSortModeGroups: availableSortModeGroups,
            contentState: .loading
        )
    }

    /// Состояние завершённого поиска.
    func results(
        query: String,
        results: SearchResults,
        selectedTrackFilterField: TrackSearchMatchField?,
        selectedSortMode: SearchSortMode,
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        displaySettings: SearchTrackDisplaySettings
    ) -> SearchScreenState {
        let trackListRows = makeTrackListRows(from: results.trackLists)
        let filteredTrackResults = trackSearchFilterBuilder.filteredResults(
            results.tracks,
            query: query,
            selectedField: selectedTrackFilterField
        )
        let sortedTrackResults = SearchResultsSorter.sort(
            filteredTrackResults,
            using: selectedSortMode
        )
        let trackRows = makeTrackRows(
            from: sortedTrackResults,
            snapshotsByTrackId: snapshotsByTrackId,
            displaySettings: displaySettings
        )
        let visibleFolders = selectedTrackFilterField == nil ? results.folders : []
        let visibleTrackLists = selectedTrackFilterField == nil ? trackListRows : []
        let chips = trackSearchFilterBuilder.chips(
            for: results.tracks,
            query: query
        )
        let availableSortModeGroups = SearchSortMode.availableModeGroups(
            for: selectedTrackFilterField
        )
        let availableSortModes = availableSortModeGroups.flatMap(\.modes)
        let contentState: SearchContentState = visibleFolders.isEmpty
            && visibleTrackLists.isEmpty
            && sortedTrackResults.isEmpty
            ? .noResults
            : .results

        return SearchScreenState(
            query: query,
            folders: visibleFolders,
            trackLists: visibleTrackLists,
            tracks: trackRows,
            trackFilterChips: chips,
            selectedTrackFilterField: selectedTrackFilterField,
            selectedSortMode: selectedSortMode,
            availableSortModes: availableSortModes,
            availableSortModeGroups: availableSortModeGroups,
            contentState: contentState
        )
    }

    /// Форматирует найденные треклисты тем же builder-ом, что и раздел треклистов.
    private func makeTrackListRows(
        from results: [SearchTrackListResult]
    ) -> [SearchTrackListRowState] {
        results.map(SearchTrackListRowState.init)
    }

    /// Форматирует найденные треки тем же runtime pipeline, что строки фонотеки.
    private func makeTrackRows(
        from results: [SearchTrackResult],
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        displaySettings: SearchTrackDisplaySettings
    ) -> [SearchTrackRowState] {
        results.map { result in
            let snapshot = snapshotsByTrackId[result.trackId]
            let displayFileName = nonEmpty(snapshot?.fileName) ?? result.fileName

            return SearchTrackRowState(
                result: result,
                artworkRequest: makeArtworkRequest(
                    result: result,
                    snapshot: snapshot,
                    shouldShowTags: displaySettings.shouldShowTags
                ),
                title: displaySettings.shouldShowTags
                    ? (nonEmpty(snapshot?.title) ?? nonEmpty(result.title) ?? displayFileName)
                    : displayFileName,
                artist: displaySettings.shouldShowTags
                    ? (nonEmpty(snapshot?.artist) ?? nonEmpty(result.artist) ?? "")
                    : "",
                duration: snapshot?.duration ?? result.duration,
                trackListNames: displaySettings.shouldShowTrackListMembership
                    ? result.trackListNames
                    : nil,
                showsFileFormat: displaySettings.shouldShowFileFormat
            )
        }
    }

    /// Собирает лёгкий запрос общей подсистемы без чтения файла в SearchView.
    private func makeArtworkRequest(
        result: SearchTrackResult,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> ArtworkRequest? {
        guard shouldShowTags else { return nil }

        return ArtworkRequest(
            trackId: result.trackId,
            snapshot: snapshot,
            purpose: .trackList
        )
    }

    /// Нормализует пустые строки, чтобы fallback работал как в строках фонотеки.
    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}
