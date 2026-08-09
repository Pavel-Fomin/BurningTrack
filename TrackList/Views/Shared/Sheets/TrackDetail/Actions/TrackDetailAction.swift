//
//  TrackDetailAction.swift
//  TrackList
//
//  Typed-действия временного сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Описывает намерения пользователя внутри Track Detail без знания manager-ов и команд.
enum TrackDetailAction {
    /// Контейнер впервые появился и должен загрузить runtime-данные.
    case appeared
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
    /// Пользователь закрыл карточку или отменил редактирование.
    case closeTapped
    /// Пользователь запросил переход к редактированию.
    case editTapped
    /// Пользователь изменил основу имени файла.
    case fileNameChanged(String)
    /// Пользователь изменил одно поле тегов.
    case fieldChanged(EditableTrackField, String)
    /// Пользователь выбрал стратегию построения имени из тегов.
    case fileNameStrategySelected(FileRenameStrategy)
    /// PhotosPicker передал выбранные байты artwork.
    case artworkSelected(data: Data, revision: UUID)
    /// Пользователь запросил удаление artwork.
    case artworkRemoveTapped
    /// Пользователь подтвердил сохранение черновика.
    case saveTapped
    /// Пользователь разрешил остановить плеер и повторить ожидающее сохранение.
    case stopPlaybackAndSaveConfirmed
    /// Пользователь закрыл системный alert.
    case alertDismissed
}
