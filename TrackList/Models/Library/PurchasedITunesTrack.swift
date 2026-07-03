//
//  PurchasedITunesTrack.swift
//  TrackList
//
//  Модель трека из системной медиатеки iOS, доступного для копирования.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Foundation

struct PurchasedITunesTrack: Identifiable, Hashable {
    /// Стабильный идентификатор элемента системной медиатеки.
    let id: UInt64
    /// Название трека для отображения в списке.
    let title: String
    /// Имя артиста, если оно есть в медиатеке.
    let artist: String?
    /// Название альбома, если оно есть в медиатеке.
    let album: String?
    /// Runtime-данные обложки из системной медиатеки; на диск не сохраняются.
    let artworkData: Data?
    /// Длительность трека в секундах.
    let duration: TimeInterval
    /// Локальный URL ассета, доступного через MediaPlayer.
    let assetURL: URL

    /// Сравниваем элементы медиатеки по persistentID, не затрагивая runtime-данные обложки.
    static func == (
        lhs: PurchasedITunesTrack,
        rhs: PurchasedITunesTrack
    ) -> Bool {
        lhs.id == rhs.id
    }

    /// Хеш строится только из стабильного persistentID системной медиатеки.
    func hash(
        into hasher: inout Hasher
    ) {
        hasher.combine(id)
    }
}
