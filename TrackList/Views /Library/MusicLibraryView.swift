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
    @StateObject private var manager = MusicLibraryManager.shared
    
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    let onAddFolder: () -> Void
    
    
    var body: some View {
        if manager.attachedFolders.isEmpty {
            VStack {
                Spacer()
                Button("Выбрать папку", action: onAddFolder)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        } else {
            List {
                ForEach(manager.attachedFolders) { folder in
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            manager.removeBookmark(for: folder.url)
                        } label: {
                            Image(systemName: "pin.slash.fill")
                        }
                    }
                }

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
