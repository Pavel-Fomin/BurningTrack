//
//  BatchTagEditViewModel.swift
//  TrackList
//
//  Владеет draft, lifecycle и асинхронными операциями Batch Tag Edit.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation

/// Единственный владелец mutable draft и presentation state feature Batch Tag Edit.
@MainActor
final class BatchTagEditViewModel: ObservableObject {
    /// View получает только готовое неизменяемое presentation-состояние.
    @Published private(set) var state: BatchTagEditScreenState

    /// Идентичность конкретного sheet-сеанса, полученная из immutable route payload.
    private let sessionID: UUID
    /// Зафиксированное действие и порядок выбранных треков для этого сеанса.
    private let pendingAction: PendingBulkTrackAction
    /// Формирует presentation state и ToastEvent.
    private let presenter: BatchTagEditPresenter
    /// Выполняет загрузку, запись, подготовку artwork и маршрутизацию.
    private let actionHandler: BatchTagEditActionHandler

    /// Полный mutable draft остаётся feature-local и никогда не передаётся SwiftUI по binding.
    private var draft: BatchTagEditFlow
    /// Флаг запрещает устаревшим завершениям менять уже закрытый сеанс.
    private var isSessionActive = true
    /// Не допускает повторный старт начальной загрузки для одного контейнера.
    private var didRequestInitialLoad = false

    /// Идентичности операций защищают UI от устаревших async-результатов.
    private var metadataOperationID: UUID?
    private var replacementOperationID: UUID?
    private var compressionOperationID: UUID?
    private var saveOperationID: UUID?
    private var reloadOperationID: UUID?

    /// UI-owned задачи отменяются при закрытии или замене operation id.
    private var metadataTask: Task<Void, Never>?
    private var replacementTask: Task<Void, Never>?
    private var compressionTask: Task<Void, Never>?
    /// Write-задача сохраняется до завершения: отмена UI не означает отмену persistence.
    private var saveTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    /// Partial result не теряется при reload: это единственное место, где пользователь видит проблемные треки.
    private var saveSummary: BatchTagEditSaveSummaryScreenState?

    init(
        sheetData: BatchTagEditSheetData,
        presenter: BatchTagEditPresenter,
        actionHandler: BatchTagEditActionHandler
    ) {
        sessionID = sheetData.id
        pendingAction = sheetData.pendingAction
        self.presenter = presenter
        self.actionHandler = actionHandler
        draft = Self.makeLoadingFlow(pendingAction: sheetData.pendingAction)
        state = presenter.makeState(from: draft)
    }

    deinit {
        metadataTask?.cancel()
        replacementTask?.cancel()
        compressionTask?.cancel()
        reloadTask?.cancel()
    }

    /// Принимает только типизированные действия UI и lifecycle контейнера.
    func send(_ action: BatchTagEditAction) {
        switch action {
        case .appeared:
            loadInitialMetadataIfNeeded()

        case .closeTapped:
            invalidateSession()
            actionHandler.close(routeID: sessionID)

        case .sheetDisappeared:
            invalidateSession()

        case .saveTapped:
            save()

        case .fieldValueChanged(let field, let value):
            updateFieldValue(value, for: field)

        case .artworkTargetSelected(let target):
            draft.artwork.selectedTarget = target
            refreshState()

        case .artworkRemoveTapped(let target):
            removeArtwork(for: target)

        case .artworkReplaceTapped(let target):
            draft.artwork.selectedTarget = target
            cancelArtworkOperations()
            draft.artwork.compressionFailureCount = 0
            refreshState()

        case .artworkReplacementSelected(let target, let data):
            prepareReplacementArtwork(data, for: target)

        case .artworkCompressTapped(let target, let option):
            compressArtwork(option: option, for: target)
        }
    }

    /// Запускает исходную загрузку по session id, а не по набору track id.
    private func loadInitialMetadataIfNeeded() {
        guard !didRequestInitialLoad, isSessionActive else { return }
        didRequestInitialLoad = true
        startMetadataLoad(restoring: nil)
    }

    /// Запускает загрузку metadata и применяет результат только к текущему operation id.
    private func startMetadataLoad(restoring selectedTarget: BatchTagArtworkActionTarget?) {
        metadataTask?.cancel()
        let operationID = UUID()
        metadataOperationID = operationID
        draft.phase = .loadingMetadata
        refreshState()

        let actionHandler = actionHandler
        let pendingAction = pendingAction
        let sessionID = sessionID
        metadataTask = Task { [weak self] in
            let loadedFlow = await actionHandler.load(pendingAction: pendingAction)
            guard !Task.isCancelled,
                  let self,
                  self.isCurrentMetadataOperation(
                    sessionID: sessionID,
                    operationID: operationID
                  ) else {
                return
            }

            var updatedFlow = loadedFlow
            if let selectedTarget {
                updatedFlow.artwork.selectedTarget = self.restoredTarget(
                    selectedTarget,
                    in: updatedFlow
                )
            }
            updatedFlow.phase = .editing
            self.draft = updatedFlow
            self.metadataOperationID = nil
            self.refreshState()
        }
    }

    /// Сохраняет current draft и затем перезагружает whole flow при любом частичном успехе.
    private func save() {
        guard isSessionActive, draft.canSave else { return }
        cancelArtworkOperations()
        let operationID = UUID()
        saveOperationID = operationID
        saveSummary = nil
        draft.phase = .saving
        refreshState()

        let savedFlow = draft
        let selectedTarget = draft.artwork.selectedTarget
        let actionHandler = actionHandler
        let sessionID = sessionID
        saveTask = Task { [weak self] in
            // Команда записи намеренно не отменяется закрытием UI: persistence имеет свой контракт.
            let result = await actionHandler.save(flow: savedFlow)
            guard let self,
                  self.isCurrentSaveOperation(
                    sessionID: sessionID,
                    operationID: operationID
                  ) else {
                return
            }

            self.saveOperationID = nil
            guard let result else {
                self.draft.phase = .editing
                self.refreshState()
                return
            }

            self.saveSummary = self.presenter.makeSaveSummary(
                for: result,
                tracks: savedFlow.tracks
            )

            if result.failedCount == 0 {
                self.presenter.presentConfirmedSave(result)
            }

            guard result.succeededCount > 0 else {
                self.draft.phase = .editing
                self.refreshState()
                return
            }

            // Reload обновляет форму подтверждёнными данными, но не стирает partial result до следующей попытки сохранения.
            self.startMetadataLoad(restoring: selectedTarget)
        }
    }

    /// Удаляет artwork и отменяет только незавершённые UI-owned artwork операции.
    private func removeArtwork(for target: BatchTagArtworkActionTarget) {
        guard isSessionActive else { return }
        cancelArtworkOperations()
        draft.artwork.selectedTarget = target
        draft.artwork.compressionFailureCount = 0
        draft.artwork.setAction(.remove, for: target)
        refreshState()
    }

    /// Нормализует выбранную artwork с двойной защитой session и revision.
    private func prepareReplacementArtwork(
        _ data: Data,
        for target: BatchTagArtworkActionTarget
    ) {
        guard isSessionActive else { return }
        replacementTask?.cancel()
        compressionTask?.cancel()
        compressionOperationID = nil
        draft.artwork.activeCompressionId = nil

        let operationID = UUID()
        replacementOperationID = operationID
        draft.artwork.selectedTarget = target
        draft.artwork.compressionFailureCount = 0
        draft.artwork.preparationProgress = BatchTagArtworkPreparationProgress(
            current: 0,
            total: 1
        )
        refreshState()

        let actionHandler = actionHandler
        let sessionID = sessionID
        replacementTask = Task { [weak self] in
            do {
                let normalizedData = try await actionHandler.prepareReplacementArtwork(data: data)
                guard !Task.isCancelled,
                      let self,
                      self.isCurrentReplacementOperation(
                        sessionID: sessionID,
                        operationID: operationID
                      ) else {
                    return
                }
                self.draft.artwork.preparationProgress = BatchTagArtworkPreparationProgress(
                    current: 1,
                    total: 1
                )
                self.draft.artwork.setAction(.replace(data: normalizedData), for: target)
                self.draft.artwork.preparationProgress = nil
                self.replacementOperationID = nil
                self.refreshState()
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.isCurrentReplacementOperation(
                        sessionID: sessionID,
                        operationID: operationID
                      ) else {
                    return
                }
                self.draft.artwork.preparationProgress = nil
                self.replacementOperationID = nil
                self.refreshState()
            }
        }
    }

    /// Сжимает выбранные artwork, сохраняя отдельные failures и идентичность операции.
    private func compressArtwork(
        option: BatchArtworkCompressionOption,
        for target: BatchTagArtworkActionTarget
    ) {
        guard isSessionActive else { return }
        replacementTask?.cancel()
        replacementOperationID = nil
        draft.artwork.preparationProgress = nil
        compressionTask?.cancel()

        let operationID = UUID()
        compressionOperationID = operationID
        draft.artwork.selectedTarget = target
        draft.artwork.activeCompressionId = operationID
        draft.artwork.compressionFailureCount = 0
        let preparation = actionHandler.makeCompressionPreparation(for: target, in: draft)

        guard !preparation.replacements.isEmpty else {
            guard draft.artwork.activeCompressionId == operationID else { return }
            draft.artwork.compressionFailureCount = preparation.failureCount
            draft.artwork.activeCompressionId = nil
            compressionOperationID = nil
            refreshState()
            return
        }
        refreshState()

        let actionHandler = actionHandler
        let sessionID = sessionID
        compressionTask = Task { [weak self] in
            let outcome = await actionHandler.compressArtwork(
                preparation.replacements,
                option: option,
                initialFailureCount: preparation.failureCount
            )
            guard !Task.isCancelled,
                  let self,
                  self.isCurrentCompressionOperation(
                    sessionID: sessionID,
                    operationID: operationID
                  ) else {
                return
            }

            for replacement in outcome.replacements {
                self.draft.artwork.setAction(
                    .replace(data: replacement.data),
                    for: .track(replacement.trackId)
                )
            }
            self.draft.artwork.compressionFailureCount = outcome.failureCount
            self.draft.artwork.activeCompressionId = nil
            self.compressionOperationID = nil
            self.refreshState()
        }
    }

    /// Обновляет group или track override согласно выбранной artwork карточке.
    private func updateFieldValue(_ value: String, for field: EditableTrackField) {
        guard isSessionActive else { return }
        if case .track(let trackId) = draft.artwork.selectedTarget {
            updateTrackFieldValue(value, for: field, trackId: trackId)
        } else {
            updateGroupFieldValue(value, for: field)
        }
        refreshState()
    }

    /// Сохраняет group-семантику: исходное значение возвращает keep.
    private func updateGroupFieldValue(_ value: String, for field: EditableTrackField) {
        guard let index = draft.fields.firstIndex(where: { $0.field == field }) else { return }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .same(let originalValue) = draft.fields[index].summary {
            let trimmedOriginalValue = originalValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue == trimmedOriginalValue {
                draft.fields[index].value = originalValue
                draft.fields[index].action = .keep
                return
            }
        }
        draft.fields[index].value = value
        draft.fields[index].action = action(for: value)
    }

    /// Сохраняет per-track override только пока значение отличается от исходного.
    private func updateTrackFieldValue(
        _ value: String,
        for field: EditableTrackField,
        trackId: UUID
    ) {
        guard let track = draft.tracks.first(where: { $0.trackId == trackId }) else { return }
        let originalValue = track.values[field] ?? ""
        let trimmedNewValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOriginalValue = originalValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedNewValue == trimmedOriginalValue {
            removeTrackFieldOverride(field, trackId: trackId)
            return
        }

        var override = draft.trackFieldOverrides[trackId] ?? BatchTagTrackFieldOverride(
            trackId: trackId,
            fields: [:]
        )
        override.fields[field] = BatchTagFieldEditState(
            field: field,
            action: action(for: value),
            value: value,
            summary: value.isEmpty ? .empty : .same(value)
        )
        draft.trackFieldOverrides[trackId] = override
    }

    /// Удаляет override, когда пользователь вернул exact исходное значение трека.
    private func removeTrackFieldOverride(_ field: EditableTrackField, trackId: UUID) {
        guard var override = draft.trackFieldOverrides[trackId] else { return }
        override.fields.removeValue(forKey: field)
        if override.fields.isEmpty {
            draft.trackFieldOverrides.removeValue(forKey: trackId)
        } else {
            draft.trackFieldOverrides[trackId] = override
        }
    }

    /// Преобразует текстовое значение в явное domain-намерение edit-поля.
    private func action(for value: String) -> BatchTagFieldEditAction {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : .set
    }

    /// Отменяет artwork-задачи и сбрасывает их техническую идентичность внутри draft.
    private func cancelArtworkOperations() {
        replacementTask?.cancel()
        compressionTask?.cancel()
        replacementOperationID = nil
        compressionOperationID = nil
        draft.artwork.preparationProgress = nil
        draft.artwork.activeCompressionId = nil
    }

    /// Делает session неактивной и прекращает только UI-owned незавершённые операции.
    private func invalidateSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        metadataTask?.cancel()
        cancelArtworkOperations()
        reloadTask?.cancel()
        metadataOperationID = nil
        reloadOperationID = nil
        // saveTask не отменяется: отмена sheet не означает отмену уже начатой записи.
    }

    /// Возвращает выбранный track, если он существует после reload, иначе summary.
    private func restoredTarget(
        _ target: BatchTagArtworkActionTarget,
        in flow: BatchTagEditFlow
    ) -> BatchTagArtworkActionTarget {
        guard case .track(let trackId) = target else { return .summary }
        return flow.artwork.previewItems.contains(where: { $0.trackId == trackId })
            ? target
            : .summary
    }

    /// Обновляет опубликованный UI-снимок только через Presenter.
    private func refreshState() {
        state = presenter.makeState(from: draft, saveSummary: saveSummary)
    }

    /// Проверяет, что результат metadata относится к открытому неизменяемому route.
    private func isCurrentMetadataOperation(sessionID: UUID, operationID: UUID) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && metadataOperationID == operationID
    }

    /// Проверяет актуальность preparation revision.
    private func isCurrentReplacementOperation(sessionID: UUID, operationID: UUID) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && replacementOperationID == operationID
    }

    /// Проверяет актуальность compression identity и draft-маркера операции.
    private func isCurrentCompressionOperation(sessionID: UUID, operationID: UUID) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && compressionOperationID == operationID
            && draft.artwork.activeCompressionId == operationID
    }

    /// Проверяет, что completion записи нельзя применить к закрытому или заменённому route.
    private func isCurrentSaveOperation(sessionID: UUID, operationID: UUID) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && saveOperationID == operationID
    }

    /// Создаёт временное loading-состояние без переноса flow в SheetManager.
    private static func makeLoadingFlow(
        pendingAction: PendingBulkTrackAction
    ) -> BatchTagEditFlow {
        BatchTagEditFlow(
            pendingAction: pendingAction,
            phase: .loadingMetadata,
            tracks: [],
            fields: [],
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
                summary: .none,
                previewSummary: BatchTagArtworkPreviewSummary(
                    selectedCount: pendingAction.trackIDs.count,
                    artworkCount: 0,
                    missingArtworkCount: pendingAction.trackIDs.count
                ),
                previewItems: [],
                selectedTarget: nil
            )
        )
    }
}
