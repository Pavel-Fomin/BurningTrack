//
//  TrackFileRenaming.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Запускает rename-flow файла трека.
@MainActor
protocol TrackFileRenaming {

    /// Обрабатывает запрос на переименование файла трека.
    func handle(_ request: TrackFileRenameRequest)
}
