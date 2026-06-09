//
//  BatchTagArtworkEditAction.swift
//  TrackList
//
//  Действие, выбранное для обложек выбранных треков.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

enum BatchTagArtworkEditAction: Equatable {
    case keep                /// Не менять обложки.
    case remove              /// Удалить обложки.
    case replace(data: Data) /// Заменить обложки новой картинкой.
}
