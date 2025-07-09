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

    var body: some View {
        if manager.attachedFolders.isEmpty {
            VStack {
                Spacer()
                Text("Папка фонотеки не выбрана")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        } else {
            List {
                ForEach(manager.attachedFolders) { folder in
                    Button {
                        path.append(folder)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
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
            }
        }
    }
}
