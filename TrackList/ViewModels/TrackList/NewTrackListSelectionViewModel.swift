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

    // MARK: - Состояние

    /// Готовое presentation-состояние корневого экрана выбора.
    @Published private(set) var state: NewTrackListSelectionState

    /// Фиксирует порядок, в котором пользователь выбрал треки.
    private var selectedTrackIDs = OrderedSelection<UUID>()
    /// Хранит треки для domain submit, не участвуя в определении их порядка.
    private var selectedTracksByID: [UUID: LibraryTrack] = [:]

    // MARK: - Зависимости

    /// Получает прикреплённые папки через явную feature-зависимость.
    private let foldersProvider: any LibraryFoldersProviding
    /// Собирает готовое presentation-состояние экрана.
    private let stateBuilder: NewTrackListSelectionStateBuilder
    /// Выполняет доменную операцию и подготовку feedback до финальной проверки session.
    private let actionHandler: NewTrackListSelectionActionHandler
    /// Не даёт late completion менять presentation-state уже закрытого route.
    private var isSessionActive = true
    /// Удерживает одну текущую submission-задачу для защиты от повторного нажатия.
    private var submissionTask: Task<Void, Never>?

    // MARK: - Инициализация

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
            selectedTrackIDs: [],
            isSubmitting: false
        )
    }

    // MARK: - Действия

    /// Обрабатывает пользовательские действия выбора и передаёт подтверждение ActionHandler-у.
    func handle(_ action: NewTrackListSelectionAction) {
        switch action {
        case .screenAppeared:
            updateState()

        case let .toggleTrack(track):
            toggle(track)

        case let .unavailableTrackTapped(track):
            actionHandler.presentUnavailableTrack(track)

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

    // MARK: - Выбор

    /// Переключает выбор одного трека.
    private func toggle(_ track: LibraryTrack) {
        if selectedTrackIDs.contains(track.id) {
            selectedTrackIDs.toggle(track.id)
            selectedTracksByID.removeValue(forKey: track.id)
        } else {
            selectedTrackIDs.toggle(track.id)
            selectedTracksByID[track.id] = track
        }

        updateState()
    }

    /// Выбирает все переданные треки.
    private func selectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            if selectedTrackIDs.contains(track.id) {
                selectedTracksByID[track.id] = track
                continue
            }

            selectedTrackIDs.toggle(track.id)
            selectedTracksByID[track.id] = track
        }

        updateState()
    }

    /// Снимает выбор со всех переданных треков.
    private func deselectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            guard selectedTrackIDs.contains(track.id) else { continue }
            selectedTrackIDs.toggle(track.id)
            selectedTracksByID.removeValue(forKey: track.id)
        }

        updateState()
    }

    /// Пересобирает единственное presentation-состояние из выбора и актуального снимка папок.
    private func updateState() {
        state = stateBuilder.build(
            folders: foldersProvider.attachedFolders,
            selectedTrackIDs: Set(selectedTrackIDs.ids),
            isSubmitting: state.isSubmitting
        )
    }

    /// Запускает одну доменную операцию, не позволяя второму submit дублировать её.
    private func submit() {
        guard state.canSubmit else { return }

        let tracks = selectedTracks
        state = stateBuilder.build(
            folders: foldersProvider.attachedFolders,
            selectedTrackIDs: Set(selectedTrackIDs.ids),
            isSubmitting: true
        )

        submissionTask = Task { [weak self] in
            guard let self else { return }

            let result = await actionHandler.submit(selectedTracks: tracks)
            guard isSessionActive else { return }

            // Подготовка одного track-style Toast может ожидать runtime snapshot, поэтому session проверяется после неё.
            let presentation = await actionHandler.preparePresentation(result)
            guard isSessionActive else { return }

            // Presentation синхронен: после этой проверки stale Toast и dismiss невозможны.
            actionHandler.present(presentation)

            state = stateBuilder.build(
                folders: foldersProvider.attachedFolders,
                selectedTrackIDs: Set(selectedTrackIDs.ids),
                isSubmitting: false
            )
        }
    }

    /// Закрывает только UI-сеанс и не отменяет уже начатую доменную операцию.
    private func invalidateSession() {
        isSessionActive = false
    }

    /// Собирает domain request строго в порядке пользовательского выбора.
    private var selectedTracks: [LibraryTrack] {
        selectedTrackIDs.ids.compactMap { selectedTracksByID[$0] }
    }
}
