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

    let playerViewModel: PlayerViewModel
    let onAddFolder: () -> Void

    // MARK: - Менеджеры

    @ObservedObject private var manager = MusicLibraryManager.shared
    @ObservedObject private var nav = NavigationCoordinator.shared
    
    @State private var showDetachAlert = false
    @State private var pendingDetachURL: URL?
    @State private var pendingDetachFolderName: String?

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
                    let isAttaching = manager.isAttachingFolder(folder.id)

                    Button {
                        if isAttaching { return }
                        nav.openFolder(folder.id) 
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            Text(folder.name)
                                .lineLimit(1)

                            Spacer()

                            if isAttaching {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAttaching)
                    .swipeActions(edge: .trailing) {
                        if isAttaching == false {
                            Button(role: .destructive) {
                                Task {
                                    let canDetach = await manager.canDetachFolder(
                                        url: folder.url,
                                        currentTrackId: playerViewModel.currentTrackDisplayable?.trackId,
                                        isPlaying: playerViewModel.isPlaying
                                    )

                                    if canDetach {
                                        do {
                                            try await manager.removeBookmark(for: folder.url)
                                            ToastManager.shared.handle(.folderRemoved(name: folder.name))
                                        } catch let appError as AppError {
                                            ToastManager.shared.handle(appError)
                                        } catch {
                                            ToastManager.shared.handle(
                                                .operationFailed(message: "Не удалось открепить папку")
                                            )
                                        }
                                    } else {
                                        await MainActor.run {
                                            pendingDetachURL = folder.url
                                            pendingDetachFolderName = folder.name
                                            showDetachAlert = true
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "pin.slash.fill")
                            }
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
                        Task {
                            do {
                                try await manager.removeBookmark(for: url)
                                ToastManager.shared.handle(.folderRemoved(name: pendingDetachFolderName ?? url.lastPathComponent))
                            } catch let appError as AppError {
                                ToastManager.shared.handle(appError)
                            } catch {
                                ToastManager.shared.handle(
                                    .operationFailed(message: "Не удалось открепить папку")
                                )
                            }
                            pendingDetachURL = nil
                            pendingDetachFolderName = nil
                        }
                    }
                }

                Button("Закрыть", role: .cancel) {
                    pendingDetachURL = nil
                    pendingDetachFolderName = nil
                }

            } message: {
                Text("Сейчас воспроизводится трек из этой папки.")
            }
        }
    }
}
