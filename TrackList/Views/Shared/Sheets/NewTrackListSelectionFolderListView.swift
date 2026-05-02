//
//  NewTrackListSelectionFolderListView.swift
//  TrackList
//
//  Список папок фонотеки для выбора треков в новый треклист.
//
//  Created by Pavel Fomin on 29.04.2026.
//

import SwiftUI

struct NewTrackListSelectionFolderListView: View {

    // MARK: - Input

    let folders: [LibraryFolder]

    // MARK: - State

    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel

    // MARK: - UI

    var body: some View {
        List {
            Section {
                ForEach(folders) { folder in
                    NavigationLink {
                        NewTrackListSelectionFolderView(
                            folder: folder,
                            selectionViewModel: selectionViewModel
                        )
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
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
