//
//  TrackDetailViewModel.swift
//  TrackList
//
//  Владеет состоянием и временным черновиком сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation

/// Изолированное baseline и draft-состояние одного edit-сеанса.
private struct TrackDetailEditSession {
    /// Неизменяемая точка отсчёта для определения реальных изменений.
    let baselineFullFileName: String
    let baselineFileName: String
    let baselineValues: [EditableTrackField: String]
    let baselineArtwork: ArtworkEditState

    /// Значения текущего несохранённого черновика.
    var fileName: String
    var editableValues: [EditableTrackField: String]
    var artwork: ArtworkEditState

    /// Создаёт чистый edit-сеанс из готового presentation-представления.
    init(content: TrackDetailLoadedPresentation) {
        baselineFullFileName = content.fullFileName
        baselineFileName = content.fileName
        baselineValues = content.editableValues
        baselineArtwork = ArtworkEditState(
            hadOriginalArtwork: content.hasOriginalArtwork
        )
        fileName = content.fileName
        editableValues = content.editableValues
        artwork = ArtworkEditState(
            hadOriginalArtwork: content.hasOriginalArtwork
        )
    }

    /// Возвращает неизменяемый draft для построения точной команды сохранения.
    func makeSaveDraft(trackId: UUID) -> TrackDetailSaveDraft {
        TrackDetailSaveDraft(
            trackId: trackId,
            baselineFullFileName: baselineFullFileName,
            baselineFileName: baselineFileName,
            baselineValues: baselineValues,
            baselineArtwork: baselineArtwork,
            fileName: fileName,
            editableValues: editableValues,
            artwork: artwork
        )
    }
}

/// Соединяет Track Detail View с ActionHandler без domain-операций в SwiftUI.
@MainActor
final class TrackDetailViewModel: ObservableObject {
    /// Единственное публикуемое состояние, подготовленное для View.
    @Published private(set) var state: TrackDetailScreenState

    /// Идентичность выбранного track displayable.
    private let track: any TrackDisplayable
    /// Начальный режим, заданный sheet route.
    private let initialMode: TrackDetailMode
    /// Преобразует данные в presentation-состояние.
    private let presenter: TrackDetailPresenter
    /// Выполняет capability-операции сценария.
    private let actionHandler: TrackDetailActionHandler
    /// Передаёт существующие runtime update events.
    private let eventProvider: any TrackDetailEventProviding

    /// Последнее подтверждённое presentation-содержимое экрана.
    private var content: TrackDetailLoadedPresentation?
    /// Purchased iTunes трек не получает editable state.
    private var isPurchasedITunes = false
    /// Временное состояние создаётся только при разрешённом входе в edit.
    private var editSession: TrackDetailEditSession?
    /// External update не затирает draft до отмены или успешного сохранения.
    private var pendingExternalSnapshot: TrackRuntimeSnapshot?
    /// Исключает повторный запуск initial load от повторного появления View.
    private var didAppear = false
    /// Хранит подписку feature-local event provider.
    private var cancellables = Set<AnyCancellable>()
    /// Не даёт completion закрытого route менять его presentation-state.
    private var isSessionActive = true
    /// UI-owned initial load отменяется после исчезновения sheet.
    private var loadTask: Task<Void, Never>?
    /// Сохранение продолжает доменную операцию после dismiss, но не меняет закрытый UI.
    private var saveTask: Task<Void, Never>?

    init(
        track: any TrackDisplayable,
        initialMode: TrackDetailMode,
        presenter: TrackDetailPresenter,
        actionHandler: TrackDetailActionHandler,
        eventProvider: any TrackDetailEventProviding
    ) {
        self.track = track
        self.initialMode = initialMode
        self.presenter = presenter
        self.actionHandler = actionHandler
        self.eventProvider = eventProvider
        self.state = TrackDetailScreenState(
            mode: .view,
            isLoading: false,
            isSaving: false,
            canEnterEdit: false,
            canSave: false,
            fileName: "",
            editableValues: [:],
            filePath: nil,
            technicalInfo: TrackDetailPresentationText.unavailableTechnicalValue,
            artwork: TrackDetailArtworkPresentationState(
                request: nil,
                canAddArtwork: false,
                canRemoveArtwork: false
            ),
            canUseFileNameStrategies: false,
            yearValidationMessage: nil,
            alert: nil
        )

        bindTrackUpdates()
    }

    /// Принимает только UI-действия и направляет их в сценарий.
    func send(_ action: TrackDetailAction) {
        switch action {
        case .appeared:
            loadIfNeeded()

        case .sheetDisappeared:
            invalidateSession()

        case .closeTapped:
            handleClose()

        case .editTapped:
            enterEditMode()

        case let .fileNameChanged(value):
            updateEditSession { $0.fileName = value }

        case let .fieldChanged(field, value):
            updateEditSession { $0.editableValues[field] = value }

        case let .fileNameStrategySelected(strategy):
            applyFileNameStrategy(strategy)

        case let .artworkSelected(data, revision):
            updateEditSession {
                $0.artwork.setNewArtwork(data: data, revision: revision)
            }

        case .artworkRemoveTapped:
            updateEditSession { $0.artwork.removeArtwork() }

        case .saveTapped:
            save()

        case .stopPlaybackAndSaveConfirmed:
            confirmStopPlayback()

        case .alertDismissed:
            rebuildState(alert: nil)
        }
    }

    /// Загружает данные единственный раз для конкретного экземпляра sheet.
    private func loadIfNeeded() {
        guard !didAppear else { return }
        didAppear = true
        rebuildState(isLoading: true, alert: nil)

        loadTask = Task { [weak self] in
            guard let self else { return }
            let result = await actionHandler.load(track: track)
            guard !Task.isCancelled, isSessionActive else { return }
            applyLoadResult(result)
        }
    }

    /// Применяет завершённую capability-загрузку к presentation state.
    private func applyLoadResult(_ result: TrackDetailLoadResult) {
        switch result {
        case let .loaded(snapshot, fileURL, isPurchasedITunes):
            content = presenter.makeLoadedPresentation(
                snapshot: snapshot,
                fileURL: fileURL
            )
            self.isPurchasedITunes = isPurchasedITunes
            pendingExternalSnapshot = nil

            if initialMode == .edit, !isPurchasedITunes, let content {
                editSession = TrackDetailEditSession(content: content)
                rebuildState(mode: .edit, isLoading: false, alert: nil)
            } else {
                editSession = nil
                rebuildState(mode: .view, isLoading: false, alert: nil)
            }

        case .unavailable:
            content = nil
            editSession = nil
            rebuildState(mode: .view, isLoading: false, alert: nil)
        }
    }

    /// Закрывает sheet в view либо отменяет только текущий edit-сеанс.
    private func handleClose() {
        guard !state.isSaving else { return }

        if state.mode == .edit {
            cancelEditing()
        } else {
            invalidateSession()
            actionHandler.close()
        }
    }

    /// Начинает editable-сеанс только для локального загруженного трека.
    private func enterEditMode() {
        guard state.canEnterEdit, let content else { return }
        editSession = TrackDetailEditSession(content: content)
        rebuildState(mode: .edit, alert: nil)
    }

    /// Отменяет draft и применяет отложенный external snapshot только после явного cancel.
    private func cancelEditing() {
        editSession = nil

        if let pendingExternalSnapshot {
            self.pendingExternalSnapshot = nil
            applySnapshot(pendingExternalSnapshot)
        } else {
            rebuildState(mode: .view, alert: nil)
        }
    }

    /// Меняет draft только в edit mode и только вне выполняемого сохранения.
    private func updateEditSession(
        _ update: (inout TrackDetailEditSession) -> Void
    ) {
        guard state.mode == .edit,
              !state.isSaving,
              var editSession else {
            return
        }

        update(&editSession)
        self.editSession = editSession
        rebuildState(alert: nil)
    }

    /// Применяет toolbar-стратегию к имени файла через action, а не Binding mutation View.
    private func applyFileNameStrategy(_ strategy: FileRenameStrategy) {
        guard var editSession,
              state.mode == .edit,
              !state.isSaving else {
            return
        }

        let artist = normalized(editSession.editableValues[.artist] ?? "")
        let title = normalized(editSession.editableValues[.title] ?? "")
        guard !artist.isEmpty, !title.isEmpty else { return }

        switch strategy {
        case .artistTitle:
            editSession.fileName = "\(artist) - \(title)"

        case .titleArtist:
            editSession.fileName = "\(title) - \(artist)"

        case .manual:
            return
        }

        self.editSession = editSession
        rebuildState(alert: nil)
    }

    /// Запускает сохранение только для валидного изменённого draft.
    private func save() {
        guard state.canSave, let editSession else { return }
        rebuildState(isSaving: true, alert: nil)
        let draft = editSession.makeSaveDraft(trackId: track.trackId)

        saveTask = Task { [weak self] in
            guard let self else { return }
            let result = await actionHandler.save(draft)
            guard !Task.isCancelled, isSessionActive else { return }
            applySaveResult(result)
        }
    }

    /// Повторяет именно отложенную команду после подтверждённого освобождения playback.
    private func confirmStopPlayback() {
        guard state.alert == .stopPlayback, !state.isSaving else { return }
        rebuildState(isSaving: true, alert: nil)

        saveTask = Task { [weak self] in
            guard let self else { return }
            let result = await actionHandler.confirmStopPlayback()
            guard !Task.isCancelled, isSessionActive else { return }
            applySaveResult(result)
        }
    }

    /// Применяет presentation-результат командного обработчика.
    private func applySaveResult(_ result: TrackDetailSavePresentation) {
        switch result {
        case let .saved(snapshot):
            pendingExternalSnapshot = nil
            editSession = nil
            applySnapshot(snapshot)

        case let .keepEditing(alert):
            rebuildState(isSaving: false, alert: alert)
        }
    }

    /// Подписывается на существующий update transport без создания нового event bus.
    private func bindTrackUpdates() {
        eventProvider.trackDidUpdate
            .sink { [weak self] event in
                guard event.trackId == self?.track.trackId else { return }
                self?.handleExternalSnapshot(event.snapshot)
            }
            .store(in: &cancellables)

        eventProvider.trackBatchDidUpdate
            .compactMap { [weak self] events in
                events.first { $0.trackId == self?.track.trackId }
            }
            .sink { [weak self] event in
                self?.handleExternalSnapshot(event.snapshot)
            }
            .store(in: &cancellables)
    }

    /// Не меняет активный draft; в view применяет событие сразу.
    private func handleExternalSnapshot(_ snapshot: TrackRuntimeSnapshot) {
        guard isSessionActive else { return }

        if state.mode == .edit {
            pendingExternalSnapshot = snapshot
            return
        }

        applySnapshot(snapshot)
    }

    /// Завершает UI-сеанс, отменяя только UI-owned загрузку runtime-данных.
    private func invalidateSession() {
        guard isSessionActive else { return }

        isSessionActive = false
        loadTask?.cancel()
    }

    /// Пересобирает подтверждённое presentation-содержимое из внешнего или save snapshot.
    private func applySnapshot(_ snapshot: TrackRuntimeSnapshot) {
        content = presenter.makeLoadedPresentation(
            snapshot: snapshot,
            fileURL: content?.fileURL
        )
        editSession = nil
        rebuildState(mode: .view, isSaving: false, alert: nil)
    }

    /// Собирает ScreenState только из presentation-данных и feature-local draft.
    private func rebuildState(
        mode: TrackDetailMode? = nil,
        isLoading: Bool? = nil,
        isSaving: Bool? = nil,
        alert: TrackDetailAlert? = nil
    ) {
        let resolvedMode = mode ?? state.mode
        let resolvedLoading = isLoading ?? state.isLoading
        let resolvedSaving = isSaving ?? state.isSaving
        let session = editSession
        let fileName = session?.fileName ?? content?.fileName ?? ""
        let values = session?.editableValues ?? content?.editableValues ?? [:]
        let artworkState = session?.artwork
            ?? ArtworkEditState(hadOriginalArtwork: content?.hasOriginalArtwork ?? false)
        let yearValidationMessage = resolvedMode == .edit
            ? presenter.yearValidationMessage(for: values[.year] ?? "")
            : nil

        state = presenter.makeState(
            mode: resolvedMode,
            isLoading: resolvedLoading,
            isSaving: resolvedSaving,
            canEnterEdit: content != nil && !isPurchasedITunes && !resolvedLoading,
            canSave: canSave(
                mode: resolvedMode,
                isSaving: resolvedSaving,
                session: session,
                yearValidationMessage: yearValidationMessage
            ),
            content: content,
            fileName: fileName,
            editableValues: values,
            artwork: presenter.makeArtworkPresentation(
                trackId: track.trackId,
                originalArtworkRequest: content?.originalArtworkRequest,
                hasOriginalArtwork: content?.hasOriginalArtwork ?? false,
                artworkEditState: artworkState
            ),
            canUseFileNameStrategies: resolvedMode == .edit
                && canBuildFileNameFromTags(values),
            yearValidationMessage: yearValidationMessage,
            alert: alert
        )
    }

    /// Сохранение доступно только при валидном реально изменённом draft.
    private func canSave(
        mode: TrackDetailMode,
        isSaving: Bool,
        session: TrackDetailEditSession?,
        yearValidationMessage: String?
    ) -> Bool {
        guard mode == .edit,
              !isSaving,
              let session,
              !normalized(session.fileName).isEmpty,
              yearValidationMessage == nil else {
            return false
        }

        return normalized(session.fileName) != normalized(session.baselineFileName)
            || normalized(session.editableValues) != normalized(session.baselineValues)
            || session.artwork != session.baselineArtwork
    }

    /// Определяет доступность готовых стратегий имени файла.
    private func canBuildFileNameFromTags(
        _ values: [EditableTrackField: String]
    ) -> Bool {
        !normalized(values[.artist] ?? "").isEmpty
            && !normalized(values[.title] ?? "").isEmpty
    }

    /// Нормализует одно редактируемое значение до сравнения.
    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Нормализует набор значений до сравнения baseline и draft.
    private func normalized(
        _ values: [EditableTrackField: String]
    ) -> [EditableTrackField: String] {
        values.mapValues(normalized)
    }
}
