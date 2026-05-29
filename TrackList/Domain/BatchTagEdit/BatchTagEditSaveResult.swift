//
//  BatchTagEditSaveResult.swift
//  TrackList
//
//  Результат массового сохранения тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Результат массового сохранения тегов.
struct BatchTagEditSaveResult {
    /// Успешно сохранённые треки.
    let succeededTrackIDs: [UUID]
    /// Ошибки по трекам.
    let failures: [BatchTagEditSaveFailure]
    /// Были ли ошибки сохранения.
    var hasFailures: Bool {
        !failures.isEmpty
    }
    /// Количество успешно сохранённых треков.
    var succeededCount: Int {
        succeededTrackIDs.count
    }
    /// Количество ошибок.
    var failedCount: Int {
        failures.count
    }
}
