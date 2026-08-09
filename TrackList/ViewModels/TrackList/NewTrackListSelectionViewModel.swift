//
//  NewTrackListSelectionViewModel.swift
//  TrackList
//
//  Состояние выбора треков для создания нового треклиста.
//
//  Created by Pavel Fomin on 29.04.2026.
//

import Foundation

@MainActor
final class NewTrackListSelectionViewModel: ObservableObject {

    // MARK: - State

    /// Готовое presentation-состояние корневого экрана выбора.
    @Published private(set) var state: NewTrackListSelectionState

    /// Выбранные треки по id.
    /// Храним сами LibraryTrack, чтобы после выбора сразу создать треклист.
    @Published private(set) var selectedTracksById: [UUID: LibraryTrack] = [:]

    // MARK: - Dependencies

    /// Получает прикреплённые папки через явную feature-зависимость.
    private let foldersProvider: any LibraryFoldersProviding
    /// Собирает готовое presentation-состояние экрана.
    private let stateBuilder: NewTrackListSelectionStateBuilder
    /// Выполняет подтверждение выбора и закрытие flow.
    private let actionHandler: NewTrackListSelectionActionHandler
    /// Не даёт late completion менять presentation-state уже закрытого route.
    private var isSessionActive = true
    /// Удерживает одну текущую submission-задачу для защиты от повторного нажатия.
    private var submissionTask: Task<Void, Never>?

    // MARK: - Init

    init(
        foldersProvider: any LibraryFoldersProviding,
        stateBuilder: NewTrackListSelectionStateBuilder,
        actionHandler: NewTrackListSelectionActionHandler
    ) {
        self.foldersProvider = foldersProvider
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.state = stateBuilder.build(
            folders: foldersProvider.attachedFolders,
            selectedCount: 0,
            isSubmitting: false
        )
    }

    /// Количество выбранных треков.
    var selectedCount: Int {
        selectedTracksById.count
    }

    /// Массив выбранных треков.
    var selectedTracks: [LibraryTrack] {
        Array(selectedTracksById.values)
    }

    /// Идентификаторы текущего выбора для готового presentation-состояния строк.
    var selectedTrackIds: Set<UUID> {
        Set(selectedTracksById.keys)
    }

    // MARK: - Actions

    /// Обрабатывает пользовательские действия выбора и передаёт подтверждение ActionHandler-у.
    func handle(_ action: NewTrackListSelectionAction) {
        switch action {
        case let .toggleTrack(track):
            toggle(track)

        case let .selectAll(tracks):
            selectAll(tracks)

        case let .deselectAll(tracks):
            deselectAll(tracks)

        case .submit:
            submit()

        case .cancel:
            invalidateSession()
            actionHandler.cancel()

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Обновляет снимок папок через явную зависимость перед показом корневого списка.
    func reloadFolders() {
        updateState()
    }

    // MARK: - Selection

    /// Проверяет, выбран ли трек.
    func isSelected(_ track: LibraryTrack) -> Bool {
        selectedTracksById[track.id] != nil
    }

    /// Переключает выбор одного трека.
    func toggle(_ track: LibraryTrack) {
        if isSelected(track) {
            selectedTracksById.removeValue(forKey: track.id)
        } else {
            selectedTracksById[track.id] = track
        }

        updateState()
    }

    /// Выбирает все переданные треки.
    func selectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            selectedTracksById[track.id] = track
        }

        updateState()
    }

    /// Снимает выбор со всех переданных треков.
    func deselectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            selectedTracksById.removeValue(forKey: track.id)
        }

        updateState()
    }

    /// Проверяет, выбраны ли все переданные треки.
    func areAllSelected(_ tracks: [LibraryTrack]) -> Bool {
        guard !tracks.isEmpty else { return false }
        return tracks.allSatisfy { selectedTracksById[$0.id] != nil }
    }

    /// Пересобирает единственное presentation-состояние из выбора и актуального снимка папок.
    private func updateState() {
        state = stateBuilder.build(
            folders: foldersProvider.attachedFolders,
            selectedCount: selectedCount,
            isSubmitting: state.isSubmitting
        )
    }

    /// Запускает одну доменную операцию, не позволяя второму submit дублировать её.
    private func submit() {
        guard state.canSubmit else { return }

        let tracks = selectedTracks
        state = stateBuilder.build(
            folders: foldersProvider.attachedFolders,
            selectedCount: selectedCount,
            isSubmitting: true
        )

        submissionTask = Task { [weak self] in
            guard let self else { return }

            let result = await actionHandler.submit(selectedTracks: tracks)
            guard isSessionActive else { return }

            await actionHandler.present(result)
            guard isSessionActive else { return }

            state = stateBuilder.build(
                folders: foldersProvider.attachedFolders,
                selectedCount: selectedCount,
                isSubmitting: false
            )
        }
    }

    /// Закрывает только UI-сеанс и не отменяет уже начатую доменную операцию.
    private func invalidateSession() {
        isSessionActive = false
    }
}
