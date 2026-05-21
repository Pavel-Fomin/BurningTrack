//
//  LibraryBatchAction.swift
//  TrackList
//
//  Batch-действия фонотеки.
//
//  Роль:
//  - описывает действия, которые пользователь может применить к выбранным трекам фонотеки;
//  - не выполняет сами действия;
//  - используется только как намерение UI.
//
//  Created by Pavel Fomin on 19.05.2026.

import Foundation

enum LibraryBatchAction {
    case addToPlayer
    case addToTrackList
    case renameFiles
    case editTags
}

extension LibraryBatchAction {
    /// Название batch-действия для отображения в UI.
    var title: String {
        switch self {
        case .addToPlayer:
            return "В плеер"
        case .addToTrackList:
            return "В треклист"
        case .renameFiles:
            return "Переименовать"
        case .editTags:
            return "Редактировать теги"
        }
    }

    /// Системная иконка batch-действия для нижней панели подтверждения.
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
