//
//  MoveToFolderContainer.swift
//  TrackList
//
//  UI-контейнер экрана выбора папки для файлового действия над треком.
//
//  Роль контейнера:
//  - владеет состоянием выбора папки назначения
//  - управляет подтверждением действия (✓) и закрытием sheet’а (×)
//  - выполняет команду, соответствующую режиму sheet’а
//  - конфигурирует NavigationBarHost
//
//  Архитектурные принципы:
//  - контейнер не содержит визуальной разметки списка папок
//  - контейнер не знает о навигации внутри дерева папок
//  - MoveToFolderSheet — чистый UI-компонент
//  - вся бизнес-логика и side-effects находятся здесь
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct MoveToFolderContainer: View {

    // MARK: - Input

    /// Данные sheet’а, переданные через SheetManager
    let data: MoveToFolderSheetData

    /// Читает текущую папку локального трека через явную factory-зависимость.
    let trackRegistry: TrackRegistry
    /// Предоставляет дерево папок листовому sheet-компоненту без singleton-доступа.
    let library: MusicLibraryManager

    /// Capability проверки занятости файла нужна только move-сценарию.
    /// Копирование iTunes-трека через неё не проходит.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Выполняет существующие команды перемещения и копирования.
    let commandExecutor: AppCommandExecutor
    /// Показывает feedback только активного UI-сеанса.
    let toastPresenter: any ToastPresenting
    /// Обрабатывает typed-закрытие текущего AppSheet без доступа View к SheetManager.
    let actionHandler: any MoveToFolderActionHandling

    // MARK: - State

    /// Выбранная папка назначения
    @State private var selectedFolderId: UUID?

    /// Текущая папка трека (для валидации и бейджа "Текущая")
    @State private var trackCurrentFolderId: UUID?
    /// Исключает повторный запуск файловой операции до завершения первой.
    @State private var isPerformingOperation = false
    /// Не даёт completion закрытого route менять UI или закрывать новый sheet.
    @State private var isSessionActive = true
    /// Отличает completion последней операции от предыдущего route или нажатия.
    @State private var operationID: UUID?

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: navigationTitle,

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только если папка выбрана и она отличается от текущей.
            /// Для iTunes-copy текущей папки нет, поэтому достаточно выбора назначения.
            isRightEnabled: Binding(
                get: {
                    selectedFolderId != nil &&
                    selectedFolderId != trackCurrentFolderId &&
                    !isPerformingOperation
                },
                set: { _ in }
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                actionHandler.handle(.closeTapped)
            },
            closeAccessibilityLabel: String(localized: "Cancel"),

            /// Подтверждение выбранной файловой операции
            onRightTap: {
                Task { await performSelectedOperation() }
            },
            rightButtonAccessibilityLabel: navigationTitle
        ) {
            MoveToFolderSheet(
                trackId: data.track.trackId,
                rootNavigationTitle: navigationTitle,
                selectedFolderId: $selectedFolderId,
                trackCurrentFolderId: $trackCurrentFolderId,
                library: library
            )
        }
        .task {
            await loadCurrentTrackFolder()
        }
        .onDisappear {
            invalidateSession()
        }
    }

    /// Заголовок sheet зависит от операции, но список папок остаётся тем же.
    private var navigationTitle: String {
        MoveToFolderPresentationText.title(for: data.operation)
    }

    // MARK: - Actions

    /// Загружает текущую папку трека для move-flow.
    /// У iTunes-трека нет папки в фонотеке, поэтому BookmarkResolver не используется.
    private func loadCurrentTrackFolder() async {
        guard data.operation == .move else {
            trackCurrentFolderId = nil
            return
        }

        if let entry = await trackRegistry.entry(for: data.track.trackId), isSessionActive {
            trackCurrentFolderId = entry.folderId
        } else if isSessionActive {
            trackCurrentFolderId = nil
        }
    }

    /// Выполняет выбранную файловую операцию только после выбора папки.
    private func performSelectedOperation() async {
        guard let folderId = selectedFolderId,
              !isPerformingOperation,
              isSessionActive else {
            return
        }

        let currentOperationID = UUID()
        operationID = currentOperationID
        isPerformingOperation = true

        switch data.operation {
        case .move:
            await moveTrack(to: folderId, operationID: currentOperationID)
        case .copyPurchasedITunes:
            await copyPurchasedITunesTrack(to: folderId, operationID: currentOperationID)
        }
    }

    /// Выполняет команду перемещения трека в выбранную папку.
    private func moveTrack(
        to folderId: UUID,
        operationID: UUID
    ) async {
        do {
            let result = try await commandExecutor.moveTrack(
                trackId: data.track.trackId,
                toFolder: folderId,
                using: fileBusyChecker
            )
            guard isCurrentOperation(operationID) else { return }
            AppCommandToastPresenter(toastPresenter: toastPresenter).present(result)
            actionHandler.handle(.operationCompleted)
        } catch let appError as AppError {
            guard isCurrentOperation(operationID) else { return }
            AppCommandToastPresenter(toastPresenter: toastPresenter).present(appError)
        } catch {
            guard isCurrentOperation(operationID) else { return }
            toastPresenter.handle(.fileMoveFailed)
        }

        finishOperationIfCurrent(operationID)
    }

    /// Передаёт iTunes-трек и выбранную папку в command-layer без прямой работы с файлами во View.
    private func copyPurchasedITunesTrack(
        to folderId: UUID,
        operationID: UUID
    ) async {
        guard let track = data.track.asPurchasedITunesPlayableTrack() else {
            guard isCurrentOperation(operationID) else { return }
            toastPresenter.handle(
                .operationFailed(
                    message: MoveToFolderPresentationText.purchasedITunesTrackPreparationFailedMessage
                )
            )
            finishOperationIfCurrent(operationID)
            return
        }

        do {
            let result = try await commandExecutor.copyPurchasedITunesTrack(
                track,
                toFolder: folderId
            )
            guard isCurrentOperation(operationID) else { return }
            AppCommandToastPresenter(toastPresenter: toastPresenter).present(result, sourceTrack: track)
            actionHandler.handle(.operationCompleted)
        } catch let appError as AppError {
            guard isCurrentOperation(operationID) else { return }
            AppCommandToastPresenter(toastPresenter: toastPresenter).present(appError)
        } catch {
            guard isCurrentOperation(operationID) else { return }
            toastPresenter.handle(
                .operationFailed(
                    message: MoveToFolderPresentationText.purchasedITunesTrackCopyFailedMessage
                )
            )
        }

        finishOperationIfCurrent(operationID)
    }

    /// Проверяет, что completion относится к последнему активному route и его операции.
    private func isCurrentOperation(_ candidateID: UUID) -> Bool {
        isSessionActive && operationID == candidateID
    }

    /// Снимает локальную блокировку только после неуспешного или незакрывающего completion.
    private func finishOperationIfCurrent(_ completedOperationID: UUID) {
        guard isCurrentOperation(completedOperationID) else { return }

        isPerformingOperation = false
        operationID = nil
    }

    /// Завершает UI-сеанс, оставляя начатую файловую команду согласованно завершиться.
    private func invalidateSession() {
        isSessionActive = false
        operationID = nil
    }
}
