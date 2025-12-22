//
//  MoveToFolderSheet.swift
//  TrackList
//
//  Экран выбора папки для перемещения трека.
//  Является UI-формой и не содержит бизнес-логики.
//
//  При выборе папки инициирует команду через AppCommandExecutor
//  и закрывается самостоятельно.
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Входные параметры

    let trackId: UUID                 /// Идентификатор перемещаемого трека
    let playerManager: PlayerManager  /// PlayerManager необходим для проверки занятости трека

    // MARK: - Состояние

    @Environment(\.dismiss) private var dismiss

    @State private var folders: [TrackRegistry.FolderEntry] = []
    @State private var currentFolderId: UUID?

    // MARK: - UI

    var body: some View {
        List(folders) { folder in
            Button {
                Task {
                    await moveTrack(to: folder.id)
                }
            } label: {
                HStack {
                    Text(folder.name)
                        .lineLimit(1)

                    Spacer()

                    // Подсветка текущей папки трека
                    if folder.id == currentFolderId {
                        Text("Текущая")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle("Переместить в папку")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFolders()
        }
    }
}

// MARK: - Вспомогательные методы

private extension MoveToFolderSheet {

    /// Загружает список папок и определяет текущую папку трека.
    func loadFolders() async {
        folders = await TrackRegistry.shared.allFolders()

        if let entry = await TrackRegistry.shared.entry(for: trackId) {
            currentFolderId = entry.folderId
        }
    }

    /// Инициирует команду перемещения трека.
    func moveTrack(to folderId: UUID) async {
        do {
            try await AppCommandExecutor.shared.moveTrack(
                trackId: trackId,
                toFolder: folderId,
                using: playerManager
            )

            // После выполнения команды закрываем sheet
            await MainActor.run {
                dismiss()
            }

        } catch {
            // Ошибки будут обрабатываться централизованно
            print("❌ Ошибка перемещения трека: \(error.localizedDescription)")
        }
    }
}
