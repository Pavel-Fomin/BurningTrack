//
//  LibraryTracksProvider.swift
//  TrackList
//
//  Объявляет асинхронное получение треков для источников фонотеки.
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


protocol LibraryTracksProvider {
    /// Возвращает треки для папки, значения раздела коллекции или общего списка фонотеки.
    func tracks(for source: LibraryTrackListSource) async -> [LibraryTrack]
}
