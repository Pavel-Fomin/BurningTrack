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
        /// Показываем всё содержимое папки: сначала подпапки, затем треки.
        case content
        /// Папка не содержит ни подпапок, ни собственных треков.
        case empty
    }

    // MARK: - Данные экрана

    let title: String
    /// Семантическая статистика папки или nil, если сохранённые данные неполные либо недоступны.
    let summary: TrackCollectionSummary?
    let folder: LibraryFolder
    let subfolders: [LibraryFolder]
    let displayMode: DisplayMode
}
