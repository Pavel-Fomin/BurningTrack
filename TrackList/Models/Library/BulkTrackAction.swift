//
//  BulkTrackAction.swift
//  TrackList
//
//  Массовые действия над выбранными треками фонотеки.
//
//  Роль:
//  - описывает намерение пользователя для bulk-операции;
//  - не выполняет операции над файлами или тегами;
//  - остаётся частью ViewModel/UI-state контракта, а не UI строки трека.
//
//  Created by Pavel Fomin on 21.05.2026.
//

import Foundation

enum BulkTrackAction {
    case addToPlayer
    case addToTrackList
    case renameFiles
    case editTags
}

extension BulkTrackAction {
    /// Название действия для отображения в toolbar и action bar.
    var title: String {
        switch self {
        case .addToPlayer:
            return "В плеер"
        case .addToTrackList:
            return "В треклист"
        case .renameFiles:
            return "Переименовать файлы"
        case .editTags:
            return "Редактировать теги"
        }
    }

    /// Системная иконка действия для нижней панели подтверждения.
    var iconName: String {
        switch self {
        case .addToPlayer:
            return "play.fill"
        case .addToTrackList:
            return "text.badge.plus"
        case .renameFiles:
            return "pencil"
        case .editTags:
            return "tag"
        }
    }
}
