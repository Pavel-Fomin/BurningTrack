//
//  TrackListAction.swift
//  TrackList
//
//  Действия detail-flow одного треклиста.
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Действия detail-flow одного треклиста.
/// View отправляет эти действия наверх, но не выполняет бизнес-логику сама.
enum TrackListAction {

    /// Экран появился.
    case onAppear

    /// Пользователь нажал на строку трека.
    case rowTapped(rowId: UUID)

    /// Пользователь запросил удаление строки из треклиста.
    case deleteTrack(rowId: UUID)

    /// Пользователь изменил порядок строк.
    case moveTrack(from: IndexSet, to: Int)

    /// Пользователь запросил добавление трека в треклист.
    case addTrack

    /// Пользователь запросил экспорт треклиста.
    case export

    /// Пользователь запросил переименование треклиста.
    case renameTrackList

    /// Пользователь нажал на обложку трека.
    case artworkTapped(rowId: UUID)

    /// Пользователь запросил переименование файла трека.
    case renameFile(rowId: UUID, strategy: FileRenameStrategy)

    /// Пользователь запросил показать трек в фонотеке.
    case showInLibrary(rowId: UUID)

    /// Пользователь запросил перемещение файла трека в папку.
    case moveToFolder(rowId: UUID)
}
