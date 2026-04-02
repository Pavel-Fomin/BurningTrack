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
    
    @State private var showDetachAlert = false
    @State private var pendingDetachURL: URL?

    var body: some View {

        // MARK: - Загрузка при первом запуске
        if manager.accessState == .booting {
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
                            Task {
                                let canDetach = await manager.canDetachFolder(
                                    url: folder.url,
                                    currentTrackId: playerViewModel.currentTrackDisplayable?.id,
                                    isPlaying: playerViewModel.isPlaying
                                )

                                if canDetach {
                                    manager.removeBookmark(for: folder.url)
                                } else {
                                    await MainActor.run {
                                        pendingDetachURL = folder.url
                                        showDetachAlert = true
                                    }
                                }
                            }
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
            .alert("Чтобы открепить папку, остановите воспроизведение", isPresented: $showDetachAlert) {

                Button("Остановить и открепить", role: .destructive) {
                    
                    // Если трек сейчас играет — ставим его на паузу
                    if playerViewModel.isPlaying {
                        playerViewModel.togglePlayPause()
                    }

                    // После остановки открепляем папку
                    if let url = pendingDetachURL {
                        manager.removeBookmark(for: url)
                    }

                    // Очищаем временно сохранённый URL
                    pendingDetachURL = nil
                }

                Button("Закрыть", role: .cancel) {
                    pendingDetachURL = nil
                }

            } message: {
                Text("Сейчас воспроизводится трек из этой папки.")
            }
        }
    }
}
