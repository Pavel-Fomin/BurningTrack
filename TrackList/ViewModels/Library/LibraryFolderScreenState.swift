//
//  LibraryFolderScreenState.swift
//  TrackList
//
//  Состояние экрана папки фонотеки.
//  View получает готовое состояние и не решает, что именно нужно показывать.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

struct LibraryFolderScreenState {
    // MARK: - Режим отображения

    enum DisplayMode {
        case subfolders
        case tracks
        case empty
    }

    // MARK: - Данные экрана

    let title: String
    let folder: LibraryFolder
    let subfolders: [LibraryFolder]
    let displayMode: DisplayMode
}
