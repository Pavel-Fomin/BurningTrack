//
//  MusicLibraryView.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @Binding var path: [LibraryFolder]
    @StateObject private var manager = MusicLibraryManager.shared
    let playerViewModel: PlayerViewModel
    let onAddFolder: () -> Void
    
    var body: some View {
        if manager.attachedFolders.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Button {
                    onAddFolder()
                } label: {
                    Text("Выбрать папку")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 0) // Ширина кнопки
                        .padding(.vertical,0)     // Высота кнопки
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        } else {
            List {
                ForEach(manager.attachedFolders) { folder in
                    Button {
                        path.append(folder)
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            manager.removeBookmark(for: folder.url)
                        } label: {
                            Label("Открепить", systemImage: "trash")
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
