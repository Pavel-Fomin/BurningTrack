//
//  TrackListPresentationHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает presentation-действия detail-flow одного треклиста.
/// Отвечает только за открытие экранов, sheet и глобальные presentation-команды.
@MainActor
final class TrackListPresentationHandler {

    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Презентер presentation-действий одного треклиста.
    private let presenter: any TrackListPresenting

    /// Создаёт обработчик presentation-действий одного треклиста.
    init(
        reader: any TrackListReading,
        presenter: any TrackListPresenting
    ) {
        self.reader = reader
        self.presenter = presenter
    }

    /// Открывает выбор трека для добавления в текущий треклист.
    func presentAddTrack() {
        guard let trackListId = reader.currentListId else { return }

        presenter.presentAddTrack(to: trackListId)
    }

    /// Открывает переименование текущего треклиста.
    func presentRenameTrackList() {
        guard let trackListId = reader.currentListId else { return }

        presenter.presentRenameTrackList(
            trackListId: trackListId,
            currentName: reader.name
        )
    }

    /// Открывает детали трека из строки треклиста.
    func presentTrackDetail(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }

        presenter.presentTrackDetail(track)
    }

    /// Показывает трек из строки треклиста в фонотеке.
    func showInLibrary(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }

        presenter.showInLibrary(track)
    }

    /// Открывает перемещение файла трека в папку.
    func moveToFolder(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }

        presenter.moveToFolder(track)
    }
}
