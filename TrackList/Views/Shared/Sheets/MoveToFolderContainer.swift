//
//  MoveToFolderContainer.swift
//  TrackList
//
//  UI-контейнер экрана перемещения трека в папку.
//
//  Роль контейнера:
//  - владеет состоянием выбора папки назначения
//  - управляет подтверждением действия (✓) и закрытием sheet’а (×)
//  - выполняет команду перемещения трека
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
    /// Будет удалён после завершения перехода на централизованный контекст плеера.
    let playerManager: PlayerManager

    // MARK: - State

    /// Выбранная папка назначения
    @State private var selectedFolderId: UUID?

    /// Текущая папка трека (для валидации и бейджа "Текущая")
    @State private var trackCurrentFolderId: UUID?

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Переместить в папку",

            isRightEnabled: Binding(
                get: {
                    selectedFolderId != nil &&
                    selectedFolderId != trackCurrentFolderId
                },
                set: { _ in }
            ),

            onClose: {
                SheetManager.shared.closeActive()
            },

            onConfirm: {
                Task { await moveTrack() }
            }
        ) {
            MoveToFolderSheet(
                trackId: data.track.id,
                selectedFolderId: $selectedFolderId,
                trackCurrentFolderId: $trackCurrentFolderId
            )
        }
        .task {
            await loadCurrentTrackFolder()
        }
    }

    // MARK: - Actions

    /// Загружает текущую папку трека.
    /// Используется для:
    /// - бейджа "Текущая" в UI
    /// - блокировки подтверждения, если папка не меняется
    private func loadCurrentTrackFolder() async {
        if let entry = await TrackRegistry.shared.entry(for: data.track.id) {
            trackCurrentFolderId = entry.folderId
        } else {
            trackCurrentFolderId = nil
        }
    }

    /// Выполняет команду перемещения трека в выбранную папку.
    /// При успешном выполнении закрывает sheet.
    private func moveTrack() async {
        guard let folderId = selectedFolderId else { return }

        do {
            try await AppCommandExecutor.shared.moveTrack(
                trackId: data.track.id,
                toFolder: folderId,
                using: playerManager
            )
            SheetManager.shared.closeActive()
        } catch {
            print("❌ Ошибка перемещения трека: \(error.localizedDescription)")
        }
    }
}
