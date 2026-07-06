//
//  TrackListsManaging.swift
//  TrackList
//
//  Контракт управления списком треклистов.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

@MainActor
protocol TrackListsManaging {

    /// Загружает метаинформацию всех треклистов.
    func loadTrackListMetas() throws -> [TrackListMeta]

    /// Удаляет треклист.
    func deleteTrackList(id: UUID) throws

    /// Переименовывает треклист.
    func renameTrackList(id: UUID, to newName: String) throws

    /// Сохраняет пользовательский порядок активных треклистов.
    func updateTrackListsOrder(_ orderedIds: [UUID]) throws
}
