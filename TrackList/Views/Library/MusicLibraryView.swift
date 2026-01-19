//
//  MusicLibraryView.swift
//  TrackList
//
//  Корневой экран фонотеки:
//  — показывает прикреплённые папки,
//  — по нажатию переходит в LibraryFolderView,
//  — не содержит логики вкладок,
//  — не использует старый route.
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {

    // MARK: - Входные данные

    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    let onAddFolder: () -> Void

    // MARK: - Менеджеры

    @ObservedObject private var manager = MusicLibraryManager.shared
    @ObservedObject private var nav = NavigationCoordinator.shared

    var body: some View {

        // MARK: - Загрузка при первом запуске
        if !manager.isInitialFoldersLoadFinished {
            VStack(spacing: 0) {
                LibraryFoldersSkeletonView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        // MARK: - Нет прикреплённых папок
        } else if manager.attachedFolders.isEmpty {
            VStack {
                Spacer()
                Button("Выбрать папку", action: onAddFolder)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        // MARK: - Папки есть → показываем список
        } else {
            List {

                ForEach(manager.attachedFolders) { folder in
                    Button {
                        nav.openFolder(folder.id) 
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            Text(folder.name)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            manager.removeBookmark(for: folder.url)
                        } label: {
                            Image(systemName: "pin.slash.fill")
                        }
                    }
                }

                // Добавить папку
                Button(action: onAddFolder) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill.badge.plus")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Добавить папку")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
