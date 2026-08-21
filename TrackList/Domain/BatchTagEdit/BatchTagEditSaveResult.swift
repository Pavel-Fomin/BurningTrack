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
    /// Индивидуально подтверждённые результаты, содержащие новый сохранённый snapshot.
    let confirmed: [BatchTagEditSaveSuccess]
    /// Ошибки по трекам.
    let failures: [BatchTagEditSaveFailure]
    /// Были ли ошибки сохранения.
    var hasFailures: Bool {
        !failures.isEmpty
    }
    /// Количество успешно сохранённых треков.
    var succeededCount: Int {
        confirmed.count
    }
    /// Количество ошибок.
    var failedCount: Int {
        failures.count
    }

    /// Идентификаторы используются presentation-слоем, но считаются только из confirmed receipt.
    var succeededTrackIDs: [UUID] {
        confirmed.map(\.trackId)
    }
}

/// Подтверждённый результат записи тегов одного трека в batch-операции.
struct BatchTagEditSaveSuccess: Identifiable {
    let trackId: UUID
    let snapshot: TrackRuntimeSnapshot

    var id: UUID {
        trackId
    }
}
