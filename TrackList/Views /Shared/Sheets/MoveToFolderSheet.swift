//
//  MoveToFolderSheet.swift
//  TrackList
//
//  Универсальный экран перемещения трека в другую папку фонотеки.
//  Работает из любого контекста: Плеер, Фонотека, Треклист.
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Входные параметры

    let trackId: UUID
    let onComplete: () -> Void

    /// PlayerManager обязателен, чтобы понимать, занят ли трек плеером.
    let playerManager: PlayerManager

    // MARK: - Состояние

    @Environment(\.dismiss) private var dismiss

    @State private var folders: [TrackRegistry.FolderEntry] = []
    @State private var currentFolderId: UUID?

    var body: some View {
        List(folders) { folder in
            Button {
                Task {
                    // Перемещаем
                    await moveTrack(to: folder.id)

                    // Закрываем sheet
                    await MainActor.run {
                        onComplete()
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    Text(folder.name)
                        .lineLimit(1)

                    Spacer()

                    // Подсветка — если это текущая папка трека
                    if folder.id == currentFolderId {
                        Text("Текущая")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Переместить в папку")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFolders() }
    }
}


// MARK: - Вспомогательные методы
private extension MoveToFolderSheet {

    /// Загружаем список всех папок + определяем, где сейчас лежит трек.
    func loadFolders() async {
        folders = await TrackRegistry.shared.allFolders()

        if let entry = await TrackRegistry.shared.entry(for: trackId) {
            currentFolderId = entry.folderId
        }
    }

    /// Перемещаем через LibraryFileManager.
    func moveTrack(to folderId: UUID) async {
        do {
            try await LibraryFileManager.shared.moveTrack(
                id: trackId,
                toFolder: folderId,
                using: playerManager
            )
            print("📁 MoveToFolderSheet: трек \(trackId) перемещён в папку \(folderId)")

        } catch {
            print("❌ Ошибка перемещения трека: \(error.localizedDescription)")
        }
    }
}
