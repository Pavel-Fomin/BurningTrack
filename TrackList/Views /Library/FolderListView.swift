//
//  FolderListView.swift
//  TrackList
//
//  Отображает список подпапок внутри LibraryFolderView
//
//  Created by Pavel Fomin on 14.08.2025.
//

import SwiftUI

struct FolderListView: View {
    let subfolders: [LibraryFolder]
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    @ObservedObject var viewModel: LibraryFolderViewModel
    @EnvironmentObject private var sheetManager: SheetManager
    
    var body: some View {
        Section {
            Section {
                ForEach(subfolders) { subfolder in
                    FolderListRowView(
                        subfolder: subfolder,
                        subfolders: subfolders,
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
}
