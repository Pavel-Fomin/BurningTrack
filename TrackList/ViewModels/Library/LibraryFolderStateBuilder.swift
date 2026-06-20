//
//  LibraryFolderStateBuilder.swift
//  TrackList
//
//  Собирает состояние экрана папки фонотеки из доменной модели LibraryFolder.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

struct LibraryFolderStateBuilder {
    // MARK: - Build

    func build(folder: LibraryFolder) -> LibraryFolderScreenState {
        LibraryFolderScreenState(
            title: folder.name,
            folder: folder,
            subfolders: folder.subfolders,
            displayMode: displayMode(for: folder)
        )
    }

    // MARK: - Private

    private func displayMode(for folder: LibraryFolder) -> LibraryFolderScreenState.DisplayMode {
        if folder.subfolders.isEmpty {
            return .tracks
        }
        return .subfolders
    }
}
