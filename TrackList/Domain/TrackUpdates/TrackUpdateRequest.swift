//
//  TrackUpdateRequest.swift
//  TrackList
//
//  Запрос на обновление runtime-состояния трека.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import Foundation

/// Запрос на обновление runtime-состояния трека после файлового изменения.
struct TrackUpdateRequest {
    /// Идентификатор трека.
    let trackId: UUID

    /// Предыдущий URL файла до переименования или перемещения.
    let previousURL: URL?
}
