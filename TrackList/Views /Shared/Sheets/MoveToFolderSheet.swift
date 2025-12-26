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

    /// Текущая папка трека (для бейджа "Текущая")
    @State private var trackCurrentFolderId: UUID?

    /// Выбранная папка назначения (radio button)
    @State private var selectedFolderId: UUID?

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {

            List(nav.rows) { row in
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
                    if row.id != trackCurrentFolderId {
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
                    
                    // Бейдж "Текущая" — справа, рядом с radio
                    if row.id == trackCurrentFolderId {
                        Text("Текущая")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
