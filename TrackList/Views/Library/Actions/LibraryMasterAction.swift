//
//  LibraryMasterAction.swift
//  TrackList
//
//  Действия корневого экрана фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

enum LibraryMasterAction {
    /// Экран появился и должен синхронизировать отображаемое состояние.
    case onAppear
    /// Пользователь запросил выбор новой папки.
    case addFolderTapped
    /// Пользователь изменил ручной порядок прикреплённых папок.
    case moveFolder(IndexSet, Int)
    /// Пользователь выбрал папку в системном picker'е.
    case folderPicked(URL)
    /// Системный picker не вернул папку.
    case folderPickFailed
    /// Пользователь открыл прикреплённую папку.
    case openFolder(UUID)
    /// Пользователь открыл виртуальный источник купленных треков iTunes.
    case openPurchasedITunes
    /// Пользователь запросил открепление папки.
    case requestDetachFolder(UUID)
    /// Пользователь подтвердил остановку воспроизведения и открепление папки.
    case confirmStopAndDetachFolder
    /// Пользователь отменил открепление папки.
    case cancelDetachFolder
}
