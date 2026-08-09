//
//  BatchFilenameRenameViewModel.swift
//  TrackList
//
//  Владеет draft, lifecycle и асинхронными операциями Batch Filename Rename.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation

/// Mutable draft существует только внутри feature-сеанса и никогда не передаётся SwiftUI напрямую.
struct BatchFilenameRenameDraft {
    /// Текущее batch-действие с выбором, сокращённым только внутри session.
    var pendingAction: PendingBulkTrackAction
    /// Подготовленные треки с fallback route до и после загрузки metadata.
    var tracks: [BatchFilenameRenameTrack]
    /// Стратегия, выбранная пользователем для текущего preview.
    var strategy: FilenameRenameStrategy?
    /// Этап lifecycle feature.
    var phase: BatchFilenameRenamePhase
    /// Строки metadata validation или готового плана.
    var items: [BatchFilenameRenameItem]
    /// Показывает и защищает UI-owned metadata preparation.
    var isPreparingMetadata: Bool
    /// Progress metadata preparation.
    var preparationProgress: BatchFilenameRenameProgress?
    /// Показывает уже начатую filesystem-операцию.
    var isApplyingRename: Bool
    /// Progress filesystem-операции.
    var applyingProgress: BatchFilenameRenameProgress?

    /// Создаёт loading draft, чтобы sheet сразу показал исходные имена immutable route.
    static func loading(
        sheetData: BatchFilenameRenameSheetData
    ) -> BatchFilenameRenameDraft {
        let initialTracks = sheetData.tracks.map(BatchFilenameRenameTrack.init(seed:))

        return BatchFilenameRenameDraft(
            pendingAction: sheetData.pendingAction,
            tracks: initialTracks,
            strategy: nil,
            phase: .loadingMetadata,
            items: [],
            isPreparingMetadata: true,
            preparationProgress: BatchFilenameRenameProgress(
                processedCount: 0,
                totalCount: initialTracks.count
            ),
            isApplyingRename: false,
            applyingProgress: nil
        )
    }
}

/// Единственный владелец feature-local draft, presentation state и защищённого async lifecycle.
@MainActor
final class BatchFilenameRenameViewModel: ObservableObject {
    /// View получает только готовый immutable снимок UI.
    @Published private(set) var state: BatchFilenameRenameScreenState

    /// Идентичность конкретного immutable sheet route.
    private let sessionID: UUID
    /// Исходные seeds не меняются, пока draft хранит локально сокращённый выбор session.
    private let routeTracks: [BatchFilenameRenameTrackSeed]
    /// Формирует presentation state вне SwiftUI View.
    private let presenter: BatchFilenameRenamePresenter
    /// Выполняет загрузку metadata, domain-планирование, apply и routing.
    private let actionHandler: BatchFilenameRenameActionHandler
    /// Полный mutable draft остаётся feature-local.
    private var draft: BatchFilenameRenameDraft
    /// Не даёт устаревшему async completion менять уже закрытый sheet-сеанс.
    private var isSessionActive = true
    /// Не допускает повторный старт начальной подготовки при повторном onAppear.
    private var didRequestInitialMetadata = false

    /// Отдельные ID отличают late result metadata и apply внутри одного session.
    private var metadataOperationID: UUID?
    private var applyOperationID: UUID?
    /// Metadata — UI-owned и отменяется при исчезновении; apply завершается согласованно.
    private var metadataTask: Task<Void, Never>?
    private var applyTask: Task<Void, Never>?

    init(
        sheetData: BatchFilenameRenameSheetData,
        presenter: BatchFilenameRenamePresenter,
        actionHandler: BatchFilenameRenameActionHandler
    ) {
        sessionID = sheetData.id
        routeTracks = sheetData.tracks
        self.presenter = presenter
        self.actionHandler = actionHandler
        draft = .loading(sheetData: sheetData)
        state = presenter.makeState(from: draft)
    }

    deinit {
        // Metadata принадлежит UI-сеансу и не должна продолжать ожидание после deinit.
        metadataTask?.cancel()
    }

    /// Принимает только типизированные действия View и lifecycle контейнера.
    func send(_ action: BatchFilenameRenameAction) {
        switch action {
        case .appeared:
            loadInitialMetadataIfNeeded()

        case .strategySelected(let strategy):
            selectStrategy(strategy)

        case .removeTrack(let trackID):
            removeTrack(trackID)

        case .renameTapped:
            applyRename()

        case .closeTapped:
            guard !state.isDismissDisabled else { return }
            invalidateSession()
            actionHandler.close(routeID: sessionID)

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Запускает metadata preparation один раз для конкретного session ID.
    private func loadInitialMetadataIfNeeded() {
        guard isSessionActive, !didRequestInitialMetadata else { return }
        didRequestInitialMetadata = true
        startMetadataLoad()
    }

    /// Загружает metadata с отдельным operation ID и применяет результат только текущему session.
    private func startMetadataLoad() {
        metadataTask?.cancel()
        let operationID = UUID()
        metadataOperationID = operationID
        draft.phase = .loadingMetadata
        draft.isPreparingMetadata = true
        draft.preparationProgress = BatchFilenameRenameProgress(
            processedCount: 0,
            totalCount: routeTracks.count
        )
        refreshState()

        let actionHandler = actionHandler
        let routeTracks = routeTracks
        let sessionID = sessionID
        metadataTask = Task { [weak self] in
            let tracks = await actionHandler.loadTracks(
                from: routeTracks,
                progress: { [weak self] processed, total in
                    guard let self,
                          self.isCurrentMetadataOperation(
                            sessionID: sessionID,
                            operationID: operationID
                          ) else {
                        return
                    }

                    self.draft.preparationProgress = BatchFilenameRenameProgress(
                        processedCount: processed,
                        totalCount: total
                    )
                    self.refreshState()
                }
            )

            guard !Task.isCancelled,
                  let self,
                  self.isCurrentMetadataOperation(
                    sessionID: sessionID,
                    operationID: operationID
                  ) else {
                return
            }

            self.draft.tracks = tracks
            self.draft.items = actionHandler.makeMetadataValidationItems(for: tracks)
            self.draft.phase = .preparing
            self.draft.isPreparingMetadata = false
            self.draft.preparationProgress = nil
            self.metadataOperationID = nil
            self.refreshState()
        }
    }

    /// Перестраивает preview выбранной стратегии без доступа View к domain-моделям.
    private func selectStrategy(_ strategy: FilenameRenameStrategy) {
        guard isSessionActive, !state.isBusy else { return }

        draft.strategy = strategy
        draft.items = actionHandler.makePlan(
            strategy: strategy,
            tracks: draft.tracks,
            preserving: draft.items
        )
        refreshState()
    }

    /// Исключает строку только из draft текущего session и сразу пересчитывает его план.
    private func removeTrack(_ trackID: UUID) {
        guard isSessionActive, !state.isBusy else { return }

        draft.tracks.removeAll { $0.trackId == trackID }
        draft.items.removeAll { $0.trackId == trackID }
        draft.pendingAction = PendingBulkTrackAction(
            action: draft.pendingAction.action,
            trackIDs: draft.pendingAction.trackIDs.filter { $0 != trackID }
        )

        if let strategy = draft.strategy {
            draft.items = actionHandler.makePlan(
                strategy: strategy,
                tracks: draft.tracks,
                preserving: draft.items
            )
        } else {
            draft.items = actionHandler.makeMetadataValidationItems(for: draft.tracks)
        }
        refreshState()
    }

    /// Запускает apply только для ready-строк и удерживает операцию после закрытия UI.
    private func applyRename() {
        guard isSessionActive, state.canApplyRename else { return }

        let commands = actionHandler.makeCommands(from: draft.items)
        guard !commands.isEmpty else { return }

        let operationID = UUID()
        applyOperationID = operationID
        draft.isApplyingRename = true
        draft.applyingProgress = BatchFilenameRenameProgress(
            processedCount: 0,
            totalCount: commands.count
        )
        refreshState()

        let actionHandler = actionHandler
        let sessionID = sessionID
        applyTask = Task { [weak self] in
            // Apply намеренно не отменяется исчезновением sheet: файловая и library-операция должна завершиться.
            let result = await actionHandler.apply(
                commands: commands,
                progress: { [weak self] processed, total in
                    guard let self,
                          self.isCurrentApplyOperation(
                            sessionID: sessionID,
                            operationID: operationID
                          ) else {
                        return
                    }

                    self.draft.applyingProgress = BatchFilenameRenameProgress(
                        processedCount: processed,
                        totalCount: total
                    )
                    self.refreshState()
                }
            )

            guard let self,
                  self.isCurrentApplyOperation(
                    sessionID: sessionID,
                    operationID: operationID
                  ) else {
                return
            }

            self.draft.items = actionHandler.apply(result: result, to: self.draft.items)
            self.draft.phase = .applied
            self.draft.isApplyingRename = false
            self.draft.applyingProgress = nil
            self.applyOperationID = nil
            self.refreshState()
        }
    }

    /// Делает session неактивной и отменяет только metadata, которой владеет UI.
    private func invalidateSession() {
        guard isSessionActive else { return }

        isSessionActive = false
        metadataTask?.cancel()
        metadataOperationID = nil
        // applyTask не отменяется: исчезновение sheet не отменяет начатое переименование файлов.
    }

    /// Обновляет опубликованное состояние единственным путём через Presenter.
    private func refreshState() {
        state = presenter.makeState(from: draft)
    }

    /// Проверяет, что metadata completion относится к открытому route и последней операции.
    private func isCurrentMetadataOperation(
        sessionID: UUID,
        operationID: UUID
    ) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && metadataOperationID == operationID
    }

    /// Проверяет, что apply completion не может изменить закрытую или заменённую UI-сессию.
    private func isCurrentApplyOperation(
        sessionID: UUID,
        operationID: UUID
    ) -> Bool {
        isSessionActive
            && self.sessionID == sessionID
            && applyOperationID == operationID
    }
}
