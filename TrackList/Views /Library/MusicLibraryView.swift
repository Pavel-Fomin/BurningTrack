//
//  MusicLibraryView.swift
//  TrackList
//
//  Главный экран фонотеки. Показывает корневые папки (attachedFolders)
//  При клике — переходит в LibraryFolderView
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @Binding var path: [LibraryFolder]
    
    @EnvironmentObject private var sheetManager: SheetManager
    @ObservedObject private var manager = MusicLibraryManager.shared
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    let onAddFolder: () -> Void
    
    
    var body: some View {
            if manager.attachedFolders.isEmpty {
                VStack {
                    Spacer()
                    Button("Прикрепить папку", action: onAddFolder)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(manager.attachedFolders, id: \.self) { folder in
                        NavigationLink(value: folder) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text(folder.name)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                        .rootFolderContextMenu(for: folder, manager: manager)
                    }
                    
                    Button(action: onAddFolder) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill.badge.plus")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Прикрепить папку")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .confirmationDialog(
                    "Удалить папку с iPhone?",
                    isPresented: Binding(
                        get: { manager.pendingDeleteURL != nil },
                        set: { newValue in
                            if !newValue {
                                manager.pendingDeleteURL = nil
                            }
                        }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Удалить", role: .destructive) {
                        if let url = manager.pendingDeleteURL {
                            manager.removeFolderAndBookmark(url: url)
                        }
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("Это удалит папку из память iPhone без возможности восстановления")
                }
                .onAppear {
                    if !manager.isAccessReady {
                        Task { await manager.restoreAccess() }
                    }
                }
            }
        
        }
    }
