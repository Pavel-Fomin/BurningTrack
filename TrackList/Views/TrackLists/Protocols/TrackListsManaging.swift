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

    /// Гарантирует наличие единственного активного системного треклиста «Избранное».
    func ensureFavoritesTrackList() throws -> TrackListMeta

    /// Возвращает активный системный треклист без создания новой записи.
    func favoritesTrackList() throws -> TrackListMeta?

    /// Загружает метаинформацию всех треклистов.
    func loadTrackListMetas() throws -> [TrackListMeta]

    /// Удаляет треклист.
    func deleteTrackList(id: UUID) throws

    /// Переименовывает треклист.
    func renameTrackList(id: UUID, to newName: String) throws

    /// Проверяет полный отображаемый порядок и сохраняет только порядок активных обычных треклистов.
    func updateTrackListsOrder(_ orderedIds: [UUID]) throws
}
