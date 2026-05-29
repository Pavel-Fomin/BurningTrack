//
//  BatchTagEditSavePlan.swift
//  TrackList
//
//  План массового сохранения тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// План массового сохранения тегов.
struct BatchTagEditSavePlan: Equatable {
    /// Команды записи для выбранных треков.
    let commands: [BatchTagEditWriteCommand]
}
