//
//  SearchViewModel.swift
//  TrackList
//
//  ViewModel раздела поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

@MainActor
final class SearchViewModel: ObservableObject {

    // MARK: - State

    /// Готовое состояние экрана поиска.
    @Published private(set) var state: SearchScreenState

    // MARK: - Dependencies

    /// Доменный сервис поиска по SQLite.
    private let searchService: any SearchServicing
    /// Управляет тем же runtime snapshot pipeline, что и строки фонотеки.
    private let runtimeController: LibraryTrackRuntimeController
    /// Даёт настройки отображения строк, общие для фонотеки и поиска.
    private let settingsManager: any SettingsManaging
    /// Показывает ошибки чтения пользователю.
    private let toastPresenter: any ToastPresenting
    /// Собирает отображаемое состояние из результатов поиска.
    private let presenter: SearchPresenter
    /// Проверяет актуальность выбранного чипа после нового результата поиска.
    private let trackSearchFilterBuilder = TrackSearchFilterBuilder()
    /// Текущая задача поиска, которую можно отменить при новом вводе.
    private var searchTask: Task<Void, Never>?
    /// Последний результат доменного поиска нужен для пересборки строк после загрузки snapshot.
    private var currentResults: SearchResults = .empty
    /// Выбранное поле фильтра треков; nil означает чип "Все".
    private var selectedTrackFilterField: TrackSearchMatchField?

    // MARK: - Init

    init(
        searchService: any SearchServicing,
        runtimeController: LibraryTrackRuntimeController,
        settingsManager: any SettingsManaging,
        toastPresenter: any ToastPresenting,
        presenter: SearchPresenter = SearchPresenter()
    ) {
        self.searchService = searchService
        self.runtimeController = runtimeController
        self.settingsManager = settingsManager
        self.toastPresenter = toastPresenter
        self.presenter = presenter
        self.state = presenter.empty()
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Actions

    /// Повторно выполняет непустой запрос при возвращении на экран.
    func refreshIfNeeded() {
        guard state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            state = presenter.empty(query: state.query)
            currentResults = .empty
            selectedTrackFilterField = nil
            return
        }

        search(query: state.query, resetsSelectedFilter: false)
    }

    /// Обновляет запрос и запускает поиск только для непустой строки.
    func updateQuery(_ query: String) {
        search(query: query, resetsSelectedFilter: true)
    }

    /// Очищает строку поиска и результат.
    func clearQuery() {
        searchTask?.cancel()
        state = presenter.empty()
        currentResults = .empty
        selectedTrackFilterField = nil
    }

    /// Выбирает чип фильтра и пересобирает текущую выдачу без нового запроса в домен.
    func selectTrackFilter(field: TrackSearchMatchField?) {
        selectedTrackFilterField = field
        state = makeResultsState(
            query: state.query,
            results: currentResults
        )
    }

    /// Запрашивает runtime snapshot для видимой строки поиска через общий pipeline фонотеки.
    func requestSnapshotIfNeeded(for trackId: UUID) {
        guard currentResults.tracks.contains(where: { $0.trackId == trackId }) else {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            _ = await runtimeController.loadSnapshotIfNeeded(for: trackId)
            guard Task.isCancelled == false else { return }

            refreshCurrentResultsIfNeeded(for: trackId)
        }
    }

    // MARK: - Search

    /// Выполняет поиск и защищает UI от результатов отменённых задач.
    private func search(query: String, resetsSelectedFilter: Bool) {
        searchTask?.cancel()

        let visibleQuery = query
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if resetsSelectedFilter {
            selectedTrackFilterField = nil
        }

        guard normalizedQuery.isEmpty == false else {
            state = presenter.empty(query: visibleQuery)
            currentResults = .empty
            selectedTrackFilterField = nil
            return
        }

        state = presenter.loading(query: visibleQuery)
        currentResults = .empty

        searchTask = Task { [weak self] in
            guard let self else { return }

            do {
                let results = try await searchService.search(query: normalizedQuery)
                guard Task.isCancelled == false else { return }

                currentResults = results
                clearUnavailableSelectedFilterIfNeeded(
                    query: visibleQuery,
                    results: results
                )
                state = makeResultsState(
                    query: visibleQuery,
                    results: results
                )
            } catch {
                guard Task.isCancelled == false else { return }

                currentResults = .empty
                selectedTrackFilterField = nil
                state = makeResultsState(
                    query: visibleQuery,
                    results: .empty
                )
                toastPresenter.handle(
                    .operationFailed(message: Self.errorMessage(from: error))
                )
            }
        }
    }

    /// Показывает конкретную ошибку доменного слоя, если она содержит текст.
    private static func errorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return "Не удалось выполнить поиск"
    }

    /// Пересобирает state, если snapshot относится к текущей выдаче.
    private func refreshCurrentResultsIfNeeded(for trackId: UUID) {
        guard currentResults.tracks.contains(where: { $0.trackId == trackId }) else {
            return
        }

        state = makeResultsState(
            query: state.query,
            results: currentResults
        )
    }

    /// Сбрасывает выбранный чип, если новое состояние поиска больше его не содержит.
    private func clearUnavailableSelectedFilterIfNeeded(
        query: String,
        results: SearchResults
    ) {
        guard selectedTrackFilterField != nil else { return }

        let containsSelectedChip = trackSearchFilterBuilder.containsChip(
            field: selectedTrackFilterField,
            results: results.tracks,
            query: query
        )

        if containsSelectedChip == false {
            selectedTrackFilterField = nil
        }
    }

    /// Собирает состояние с текущими runtime snapshot и настройками отображения фонотеки.
    private func makeResultsState(
        query: String,
        results: SearchResults
    ) -> SearchScreenState {
        let visibleSettings = settingsManager.settings.visible
        let displaySettings = SearchTrackDisplaySettings(
            shouldShowTags: visibleSettings.metadata.isTagReadingEnabled,
            shouldShowTrackListMembership: visibleSettings.library.isTrackListMembershipVisible,
            shouldShowFileFormat: visibleSettings.library.isFileFormatVisible
        )

        return presenter.results(
            query: query,
            results: results,
            selectedTrackFilterField: selectedTrackFilterField,
            snapshotsByTrackId: runtimeController.snapshotsByTrackId,
            displaySettings: displaySettings
        )
    }
}
