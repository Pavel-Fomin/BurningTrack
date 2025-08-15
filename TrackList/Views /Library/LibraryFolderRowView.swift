//
//  LibraryFolderRowView.swift
//  TrackList
//
//  Отображает одну папку: иконка + название
//
//  Created by Pavel Fomin on 14.08.2025.
//

import Foundation
import SwiftUI

struct FolderRowView: View {
    let folder: LibraryFolder

    var body: some View {
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
