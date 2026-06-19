//
//  TrackListMutationHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает изменения содержимого одного треклиста.
/// Отвечает за удаление, перемещение и действия, которые меняют данные строк.
@MainActor
final class TrackListMutationHandler {

    /// Выполняет изменения треклиста.
    private let mutator: any TrackListMutating

    /// Создаёт обработчик изменений одного треклиста.
    init(mutator: any TrackListMutating) {
        self.mutator = mutator
    }

    /// Удаляет трек из текущего треклиста по идентификатору строки.
    func deleteTrack(rowId: UUID) {
        guard let index = mutator.tracks.firstIndex(where: { $0.id == rowId }) else { return }

        mutator.removeTrack(at: IndexSet(integer: index))
    }

    /// Перемещает треки внутри текущего треклиста.
    func moveTrack(
        from source: IndexSet,
        to destination: Int
    ) {
        mutator.moveTrack(
            from: source,
            to: destination
        )
    }

}
