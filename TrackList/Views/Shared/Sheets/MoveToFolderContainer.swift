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

    /// PlayerManager временно пробрасывается для выполнения команды перемещения.
    /// Копирование iTunes-трека через этот объект не проходит.
    let playerManager: PlayerManager

    // MARK: - State

    /// Выбранная папка назначения
    @State private var selectedFolderId: UUID?

    /// Текущая папка трека (для валидации и бейджа "Текущая")
    @State private var trackCurrentFolderId: UUID?

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
                    selectedFolderId != trackCurrentFolderId
                },
                set: { _ in }
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                SheetManager.shared.closeActive()
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
                trackCurrentFolderId: $trackCurrentFolderId
            )
        }
        .task {
            await loadCurrentTrackFolder()
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

        if let entry = await TrackRegistry.shared.entry(for: data.track.trackId) {
            trackCurrentFolderId = entry.folderId
        } else {
            trackCurrentFolderId = nil
        }
    }

    /// Выполняет выбранную файловую операцию только после выбора папки.
    private func performSelectedOperation() async {
        guard let folderId = selectedFolderId else { return }

        switch data.operation {
        case .move:
            await moveTrack(to: folderId)
        case .copyPurchasedITunes:
            await copyPurchasedITunesTrack(to: folderId)
        }
    }

    /// Выполняет команду перемещения трека в выбранную папку.
    private func moveTrack(
        to folderId: UUID
    ) async {
        do {
            try await AppCommandExecutor.shared.moveTrack(
                trackId: data.track.trackId,
                toFolder: folderId,
                using: playerManager
            )
            SheetManager.shared.closeActive()
        } catch let appError as AppError {
            ToastManager.shared.handle(appError)
        } catch {
            ToastManager.shared.handle(.fileMoveFailed)
        }
    }

    /// Передаёт iTunes-трек и выбранную папку в command-layer без прямой работы с файлами во View.
    private func copyPurchasedITunesTrack(
        to folderId: UUID
    ) async {
        guard let track = data.track.asPurchasedITunesPlayableTrack() else {
            ToastManager.shared.handle(
                .operationFailed(
                    message: MoveToFolderPresentationText.purchasedITunesTrackPreparationFailedMessage
                )
            )
            return
        }

        do {
            try await AppCommandExecutor.shared.copyPurchasedITunesTrack(
                track,
                toFolder: folderId
            )
            SheetManager.shared.closeActive()
        } catch let appError as AppError {
            ToastManager.shared.handle(appError)
        } catch {
            ToastManager.shared.handle(
                .operationFailed(
                    message: MoveToFolderPresentationText.purchasedITunesTrackCopyFailedMessage
                )
            )
        }
    }
}
