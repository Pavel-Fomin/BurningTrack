//
//  TrackFileRenaming.swift
//  TrackList
//
//  Объявляет capability запуска общего rename-flow файла трека.
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
