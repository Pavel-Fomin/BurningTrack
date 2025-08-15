//
//  FolderListRowView.swift
//  TrackList
//
//  Компонент строки списка
//
//  Created by Pavel Fomin on 14.08.2025.
//

import Foundation
import SwiftUI

struct FolderListRowView: View {
    let subfolder: LibraryFolder
    let subfolders: [LibraryFolder]
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    @ObservedObject var viewModel: LibraryFolderViewModel
    @EnvironmentObject private var sheetManager: SheetManager

    var body: some View {
            NavigationLink(
                destination: LibraryFolderView(
                    folder: subfolder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel,
                    viewModel: LibraryFolderViewModel(folder: subfolder)
                    
                )
            ) {
                FolderRowView(folder: subfolder)
            }
            .folderContextMenu(
                folder: subfolder,
                siblings: subfolders,
                viewModel: viewModel
            )
        }
    }
