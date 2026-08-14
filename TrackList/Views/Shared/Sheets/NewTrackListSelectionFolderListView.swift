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

    // MARK: - Входные данные

    let folders: [LibraryFolder]
    /// Собирает дочерний экран папки через feature-factory.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    // MARK: - Состояние

    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel

    // MARK: - Интерфейс

    var body: some View {
        List {
            Section {
                ForEach(folders) { folder in
                    NavigationLink {
                        folderViewFactory.makeFolderContainer(
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
