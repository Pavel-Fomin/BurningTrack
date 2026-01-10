//
//  MoveToFolderSheet.swift
//  TrackList
//
//  Экран выбора папки для перемещения трека.
//  Является UI-формой и не содержит бизнес-логики.
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Входные параметры

    let trackId: UUID
    let playerManager: PlayerManager

    // MARK: - Состояние

    @Environment(\.dismiss) private var dismiss
    @StateObject private var nav = MoveToFolderNavigationContext(library: MusicLibraryManager.shared)
    @State private var trackCurrentFolderId: UUID? /// Текущая папка трека (для бейджа "Текущая")
    @State private var selectedFolderId: UUID?     /// Выбранная папка назначения (radio button)
    
    // MARK: - Строки папок для отображения в списке
    
    /// - текущая папка трека показывается виртуально ТОЛЬКО на корневом уровне
    /// - внутри дерева отображается только естественным образом
    private var orderedRows: [MoveToFolderNavigationContext.FolderRow] {

        let rows = nav.rows

        // Пока текущая папка ещё не загружена — показываем список как есть
        guard let currentId = trackCurrentFolderId else {
            return rows
        }

        // Если текущая папка уже есть в списке — просто поднимаем её наверх
        if rows.contains(where: { $0.id == currentId }) {
            return rows.sorted { lhs, rhs in
                if lhs.id == currentId { return true }
                if rhs.id == currentId { return false }
                return false
            }
        }

        // Виртуально добавляем текущую папку ТОЛЬКО на корневом уровне
        guard nav.currentFolderId == nil else {
            return rows
        }

        // Добавляем текущую папку сверху
        guard let currentFolder = MusicLibraryManager.shared.folder(for: currentId) else {
            return rows
        }

        let currentRow = MoveToFolderNavigationContext.FolderRow(
            id: currentId,
            name: currentFolder.name,
            hasSubfolders: currentFolder.subfolders.isEmpty == false
        )

        return [currentRow] + rows
    }

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {

            List(orderedRows) { row in
                HStack(spacing: 12) {

                    // Левая зона — навигация (переход в подпапку)
                    Button {
                        nav.enter(row.id)
                    } label: {
                        HStack(spacing: 10) {
                            Text(row.name).lineLimit(1)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Правая зона — выбор папки назначения (radio)
                    // Показывается ТОЛЬКО для папок без подпапок и не для текущей папки
                    if row.id != trackCurrentFolderId && row.hasSubfolders == false {
                        Button {
                            selectedFolderId = (selectedFolderId == row.id) ? nil : row.id
                        } label: {
                            Image(systemName: selectedFolderId == row.id
                                  ? "largecircle.fill.circle"
                                  : "circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Пустое место под radio, чтобы не ломать layout
                        Spacer()
                            .frame(width: 28)
                    }
                    
                }
                .overlay(alignment: .trailing) {
                    
                    // Бейдж "Текущая"
                    if row.id == trackCurrentFolderId {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                    }
                }
                .listRowBackground(Color(.tertiarySystemBackground))
            }
        }
        .navigationTitle(nav.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Кнопка "Назад" появляется только если мы реально углубились
            ToolbarItem(placement: .topBarLeading) {
                if nav.canGoBack {
                    Button {
                        nav.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Переместить") {
                Task { await moveSelected() }
            }
            .disabled(selectedFolderId == nil || selectedFolderId == trackCurrentFolderId)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .task { await loadCurrentTrackFolder() }
    }
}

// MARK: - Вспомогательные методы

private extension MoveToFolderSheet {

    /// Определяем текущую папку трека для бейджа "Текущая".
    func loadCurrentTrackFolder() async {
        if let entry = await TrackRegistry.shared.entry(for: trackId) {
            trackCurrentFolderId = entry.folderId
        } else {
            trackCurrentFolderId = nil
        }
    }

    /// Инициирует команду перемещения трека в выбранную папку.
    func moveSelected() async {
        guard let folderId = selectedFolderId else { return }

        do {
            try await AppCommandExecutor.shared.moveTrack(
                trackId: trackId,
                toFolder: folderId,
                using: playerManager
            )

            // После выполнения команды закрываем sheet
            await MainActor.run { SheetManager.shared.closeActive() }

        } catch {
            print("❌ Ошибка перемещения трека: \(error.localizedDescription)")
        }
    }
}
