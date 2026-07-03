//
//  TrackListScreenState.swift
//  TrackList
//
//  Состояние экрана одного треклиста.
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation
import UIKit

/// Состояние экрана одного треклиста.
/// View получает готовое состояние и не должна сама читать менеджеры или ViewModel.
struct TrackListScreenState {

    /// Идентификатор треклиста.
    let id: UUID

    /// Название треклиста для заголовка.
    let title: String

    /// Строки треков.
    let rows: [TrackListRowState]

    /// Идентификатор строки, к которой нужно проскроллить список.
    let scrollTargetRowId: UUID?
}

/// Состояние строки трека в одном треклисте.
/// Сюда уже должны быть подготовлены title, artist, artwork и флаги отображения.
struct TrackListRowState: Identifiable {

    /// Идентификатор строки в треклисте.
    let id: UUID

    /// Идентификатор физического трека.
    let trackId: UUID

    /// Название для отображения.
    let title: String

    /// Исполнитель для отображения.
    let artist: String

    /// Имя файла.
    let fileName: String

    /// Источник трека для контекстного меню.
    let source: TrackSource

    /// Длительность трека.
    let duration: TimeInterval

    /// Доступен ли файл трека.
    let isAvailable: Bool

    /// Является ли строка текущим треком.
    let isCurrent: Bool

    /// Воспроизводится ли текущая строка.
    let isPlaying: Bool

    /// Нужно ли подсветить строку.
    let isHighlighted: Bool

    /// Обложка для отображения.
    let artwork: UIImage?

    /// Показывать ли формат файла.
    let showsFileFormat: Bool

    /// Исполнитель для rename-menu.
    let renameArtist: String?

    /// Название для rename-menu.
    let renameTitle: String?
}
