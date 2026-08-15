//
//  MoveToFolderActionHandler.swift
//  TrackList
//
//  Выполняет lifecycle и команды Move To Folder вне SwiftUI.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Описывает пользовательские и lifecycle-намерения Move To Folder.
enum MoveToFolderAction {
    /// Sheet появился и feature должен подготовить начальное состояние.
    case screenAppeared
    /// Пользователь выбрал или снял выбор папки назначения.
    case folderSelectionChanged(UUID?)
    /// Пользователь подтвердил операцию перемещения или копирования.
    case submitTapped
    /// Пользователь явно отказался от выбора папки.
    case closeTapped
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
}

/// Владеет mutable feature-state, operation identity и route/session защитой.
@MainActor
final class MoveToFolderActionHandler {
    /// Immutable payload конкретного sheet route.
    private let data: MoveToFolderSheetData
    /// Готовый snapshot папок, не требующий manager lookup в View.
    private let folderSnapshot: MoveToFolderFolderSnapshot
    /// Читает current folder только для local move ветки.
    private let trackRegistry: any MoveToFolderTrackRegistryReading
    /// Сохраняет file busy semantics существующей move-команды.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Выполняет существующие domain-команды без их дублирования в feature.
    private let commandExecutor: any MoveToFolderCommandExecuting
    /// Показывает success и failure feedback только актуальной UI-сессии.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует закрытие только активного Move To Folder AppSheet.
    private let router: any MoveToFolderRouting
    /// Неизменяемая идентичность конкретного route одновременно является session identity.
    private let routeID: UUID
    /// Формирует и публикует готовый ScreenState.
    private let presenter: MoveToFolderPresenter

    /// Пользовательский выбор destination в рамках текущего feature-сеанса.
    private var selectedFolderID: UUID?
    /// Папка source local-трека после завершения initial load.
    private var currentFolderID: UUID?
    /// Исключает повторный submit до завершения текущей domain-команды.
    private var isPerformingOperation = false
    /// Не даёт закрытому route публиковать поздние initial-load или operation completion.
    private var isSessionActive = true
    /// Исключает повторную initial load при повторной materialization SwiftUI.
    private var didRequestInitialLoad = false
    /// Отличает актуальную initial load конкретного route от late completion.
    private var initialLoadOperationID: UUID?
    /// Отличает completion текущей domain-команды от stale callback.
    private var operationID: UUID?
    /// Initial lookup принадлежит UI-session и может быть отменён при его завершении.
    private var initialLoadTask: Task<Void, Never>?
    /// Начатая domain-операция намеренно не отменяется при закрытии sheet.
    private var operationTask: Task<Void, Never>?

    /// Собирает owner команд только из зависимостей, подготовленных feature factory.
    init(
        data: MoveToFolderSheetData,
        folderSnapshot: MoveToFolderFolderSnapshot,
        trackRegistry: any MoveToFolderTrackRegistryReading,
        fileBusyChecker: any TrackFileBusyChecking,
        commandExecutor: any MoveToFolderCommandExecuting,
        toastPresenter: any ToastPresenting,
        router: any MoveToFolderRouting,
        presenter: MoveToFolderPresenter
    ) {
        self.data = data
        self.folderSnapshot = folderSnapshot
        self.trackRegistry = trackRegistry
        self.fileBusyChecker = fileBusyChecker
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.router = router
        routeID = data.id
        self.presenter = presenter
    }

    deinit {
        // Initial lookup принадлежит UI-сеансу; operationTask должен завершить domain-команду сам.
        initialLoadTask?.cancel()
    }

    /// Маршрутизирует все intent View в один feature-local owner.
    func handle(_ action: MoveToFolderAction) {
        switch action {
        case .screenAppeared:
            prepareInitialStateIfNeeded()

        case let .folderSelectionChanged(folderID):
            guard isSessionActive else { return }
            selectedFolderID = folderID
            presentState()

        case .submitTapped:
            startSelectedOperation()

        case .closeTapped:
            guard isSessionActive else { return }
            invalidateSession()
            router.dismissMoveToFolder(routeID)

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Публикует базовое состояние один раз и загружает current folder только для local move.
    private func prepareInitialStateIfNeeded() {
        guard isSessionActive, didRequestInitialLoad == false else { return }
        didRequestInitialLoad = true
        presentState()

        guard data.operation == .move else { return }

        let currentInitialLoadID = UUID()
        initialLoadOperationID = currentInitialLoadID
        let trackRegistry = trackRegistry
        let trackID = data.track.trackId
        let routeID = routeID

        initialLoadTask = Task { [weak self] in
            let entry = await trackRegistry.entry(for: trackID)
            guard let self,
                  self.isCurrentInitialLoad(
                    routeID: routeID,
                    operationID: currentInitialLoadID
                  ) else {
                return
            }

            currentFolderID = entry?.folderId
            initialLoadOperationID = nil
            initialLoadTask = nil
            presentState()
        }
    }

    /// Запускает ровно одну domain-команду для валидной выбранной папки.
    private func startSelectedOperation() {
        guard isSessionActive,
              let selectedFolderID,
              selectedFolderID != currentFolderID,
              isPerformingOperation == false else {
            return
        }

        let currentOperationID = UUID()
        operationID = currentOperationID
        isPerformingOperation = true
        presentState()

        switch data.operation {
        case .move:
            startMove(
                to: selectedFolderID,
                operationID: currentOperationID
            )

        case .copyPurchasedITunes:
            startPurchasedITunesCopy(
                to: selectedFolderID,
                operationID: currentOperationID
            )
        }
    }

    /// Выполняет существующую local move-команду, не удерживая SwiftUI View.
    private func startMove(
        to folderID: UUID,
        operationID: UUID
    ) {
        let commandExecutor = commandExecutor
        let fileBusyChecker = fileBusyChecker
        let trackID = data.track.trackId

        operationTask = Task { [weak self] in
            do {
                let result = try await commandExecutor.moveTrack(
                    trackId: trackID,
                    toFolder: folderID,
                    using: fileBusyChecker
                )
                self?.handleMoveSuccess(result, operationID: operationID)
            } catch let appError as AppError {
                self?.handleAppError(appError, operationID: operationID)
            } catch {
                self?.handleMoveFailure(operationID: operationID)
            }
        }
    }

    /// Подготавливает Purchased iTunes payload и запускает отдельную copy-ветку без TrackRegistry.
    private func startPurchasedITunesCopy(
        to folderID: UUID,
        operationID: UUID
    ) {
        guard let track = data.track.asPurchasedITunesPlayableTrack() else {
            guard isCurrentOperation(operationID) else { return }
            toastPresenter.handle(
                .operationFailed(
                    message: MoveToFolderPresentationText
                        .purchasedITunesTrackPreparationFailedMessage
                )
            )
            finishOperationIfCurrent(operationID)
            return
        }

        let commandExecutor = commandExecutor
        operationTask = Task { [weak self] in
            do {
                let result = try await commandExecutor.copyPurchasedITunesTrack(
                    track,
                    toFolder: folderID
                )
                self?.handlePurchasedITunesCopySuccess(
                    result,
                    sourceTrack: track,
                    operationID: operationID
                )
            } catch let appError as AppError {
                self?.handleAppError(appError, operationID: operationID)
            } catch {
                self?.handlePurchasedITunesCopyFailure(operationID: operationID)
            }
        }
    }

    /// Показывает move success и завершает только совпадающий route.
    private func handleMoveSuccess(
        _ result: MoveTrackSuccess,
        operationID: UUID
    ) {
        guard isCurrentOperation(operationID) else { return }
        AppCommandToastPresenter(toastPresenter: toastPresenter).present(result)
        finishSuccessfulOperation(operationID)
    }

    /// Показывает Purchased iTunes copy success и завершает только совпадающий route.
    private func handlePurchasedITunesCopySuccess(
        _ result: CopyPurchasedITunesTrackSuccess,
        sourceTrack: PurchasedITunesPlayableTrack,
        operationID: UUID
    ) {
        guard isCurrentOperation(operationID) else { return }
        AppCommandToastPresenter(toastPresenter: toastPresenter).present(
            result,
            sourceTrack: sourceTrack
        )
        finishSuccessfulOperation(operationID)
    }

    /// Сохраняет существующий AppError → AppCommandToastPresenter mapping.
    private func handleAppError(
        _ error: AppError,
        operationID: UUID
    ) {
        guard isCurrentOperation(operationID) else { return }
        AppCommandToastPresenter(toastPresenter: toastPresenter).present(error)
        finishOperationIfCurrent(operationID)
    }

    /// Сохраняет отдельный generic error local move-ветки.
    private func handleMoveFailure(operationID: UUID) {
        guard isCurrentOperation(operationID) else { return }
        toastPresenter.handle(.fileMoveFailed)
        finishOperationIfCurrent(operationID)
    }

    /// Сохраняет отдельный generic error Purchased iTunes copy-ветки.
    private func handlePurchasedITunesCopyFailure(operationID: UUID) {
        guard isCurrentOperation(operationID) else { return }
        toastPresenter.handle(
            .operationFailed(
                message: MoveToFolderPresentationText
                    .purchasedITunesTrackCopyFailedMessage
            )
        )
        finishOperationIfCurrent(operationID)
    }

    /// Завершает success до dismiss, чтобы callback больше не мог менять закрывающийся route.
    private func finishSuccessfulOperation(_ completedOperationID: UUID) {
        guard isCurrentOperation(completedOperationID) else { return }
        invalidateSession()
        router.dismissMoveToFolder(routeID)
    }

    /// Возвращает screen в idle после ошибки, оставляя выбранную папку для повторной попытки.
    private func finishOperationIfCurrent(_ completedOperationID: UUID) {
        guard isCurrentOperation(completedOperationID) else { return }
        isPerformingOperation = false
        operationID = nil
        operationTask = nil
        presentState()
    }

    /// Делает UI-сеанс stale, не отменяя уже переданную domain-команду.
    private func invalidateSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        initialLoadTask?.cancel()
        initialLoadOperationID = nil
        operationID = nil
    }

    /// Проверяет принадлежность initial load текущему route и его активному UI-сеансу.
    private func isCurrentInitialLoad(
        routeID: UUID,
        operationID: UUID
    ) -> Bool {
        isSessionActive
            && self.routeID == routeID
            && initialLoadOperationID == operationID
    }

    /// Проверяет принадлежность completion текущему route и конкретной operation.
    private func isCurrentOperation(_ candidateID: UUID) -> Bool {
        isSessionActive && operationID == candidateID
    }

    /// Пересобирает UI исключительно через Presenter.
    private func presentState() {
        presenter.present(
            navigationTitle: MoveToFolderPresentationText.title(for: data.operation),
            folderSnapshot: folderSnapshot,
            selectedFolderID: selectedFolderID,
            currentFolderID: currentFolderID,
            isPerformingOperation: isPerformingOperation
        )
    }
}

/// Закрывает конкретный Move To Folder route через общий lifecycle SheetManager.
@MainActor
protocol MoveToFolderRouting: AnyObject {

    /// Начинает dismiss, только если сейчас отображается совпадающий Move To Folder route.
    func dismissMoveToFolder(_ routeID: UUID)
}

extension SheetManager: MoveToFolderRouting {}
