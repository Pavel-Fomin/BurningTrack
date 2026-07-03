//
//  TrackListPresenting.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Презентер действий detail-flow одного треклиста.
@MainActor
protocol TrackListPresenting {
    /// Открывает выбор трека для добавления в треклист.
    func presentAddTrack(to trackListId: UUID)

    /// Открывает переименование треклиста.
    func presentRenameTrackList(
        trackListId: UUID,
        currentName: String
    )

    /// Открывает детали трека.
    func presentTrackDetail(_ track: Track)

    /// Открывает копирование купленного iTunes-трека.
    func presentCopyPurchasedITunesTrack(_ track: PurchasedITunesPlayableTrack)

    /// Открывает редактирование тегов трека.
    func presentTrackTagsEditor(_ track: Track)

    /// Показывает трек в фонотеке.
    func showInLibrary(_ track: Track)

    /// Открывает перемещение файла трека в папку.
    func moveToFolder(_ track: Track)
}
