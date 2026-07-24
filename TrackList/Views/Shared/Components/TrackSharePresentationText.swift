//
//  TrackSharePresentationText.swift
//  TrackList
//
//  Локализованные подписи сценария отправки одного трека.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Преобразует семантические состояния отправки в локализованный текст интерфейса.
enum TrackSharePresentationText {
    /// Название действия в меню трека.
    static var actionTitle: String {
        String(localized: "track.share.action")
    }

    /// Заголовок alert для недоступного iTunes-трека.
    static var unavailableTitle: String {
        String(localized: "track.share.unavailable.title")
    }

    /// Причина, которая не предлагает несуществующую загрузку через BurningTrack.
    static var unavailableMessage: String {
        String(localized: "track.share.unavailable.message")
    }

    /// Стандартная кнопка закрытия системного alert.
    static var acknowledgeTitle: String {
        String(localized: "OK")
    }
}
