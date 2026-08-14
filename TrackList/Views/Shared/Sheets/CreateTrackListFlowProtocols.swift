//
//  CreateTrackListFlowProtocols.swift
//  TrackList
//
//  Контракты зависимостей feature-flow создания и выбора треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Выполняет доменные операции, необходимые только для создания и пополнения треклистов.
@MainActor
protocol TrackListFlowManaging {
    /// Создаёт пустой треклист с именем пользователя.
    func createEmptyTrackList(withName name: String) throws -> TrackList
    /// Создаёт треклист из выбранных треков фонотеки.
    func createTrackList(from libraryTracks: [LibraryTrack], withName name: String) throws -> TrackList
    /// Возвращает метаданные треклистов для определения имени append-цели.
    func loadTrackListMetas() throws -> [TrackListMeta]
    /// Добавляет выбранные треки в существующий треклист.
    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> Bool
}

/// Предоставляет готовое дерево прикреплённых папок без обращения View к менеджеру фонотеки.
@MainActor
protocol LibraryFoldersProviding {
    /// Текущий снимок прикреплённых корневых папок.
    var attachedFolders: [LibraryFolder] { get }
}

/// Маршрутизирует действия sheet создания треклиста.
@MainActor
protocol CreateTrackListRouting {
    /// Закрывает только route создания треклиста с переданной идентичностью.
    func dismissCreateTrackList(_ routeID: UUID)
    /// Открывает выбор треков только из совпадающего route создания.
    func presentTrackSelectionForCreate(name: String, from routeID: UUID)
}

/// Маршрутизирует завершение sheet выбора треков.
@MainActor
protocol NewTrackListSelectionRouting {
    /// Закрывает только route выбора треков с переданной идентичностью.
    func dismissNewTrackListSelection(_ routeID: UUID)
}

// MARK: - Адаптеры production-слоя

extension TrackListsManager: TrackListFlowManaging {}

extension MusicLibraryManager: LibraryFoldersProviding {}

extension SheetManager: CreateTrackListRouting {}

extension SheetManager: NewTrackListSelectionRouting {}
