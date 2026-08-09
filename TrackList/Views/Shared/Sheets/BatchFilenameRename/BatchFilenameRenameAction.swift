//
//  BatchFilenameRenameAction.swift
//  TrackList
//
//  Типизированные действия feature массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Описывает пользовательские намерения и lifecycle-события Batch Filename Rename.
enum BatchFilenameRenameAction {
    /// Контейнер появился и может начать подготовку metadata route.
    case appeared
    /// Пользователь выбрал формат нового имени файла.
    case strategySelected(FilenameRenameStrategy)
    /// Пользователь исключил трек только из текущей feature-сессии.
    case removeTrack(UUID)
    /// Пользователь запустил физическое переименование готовых строк.
    case renameTapped
    /// Пользователь запросил закрытие sheet.
    case closeTapped
    /// SwiftUI сообщил, что sheet действительно исчез.
    case sheetDisappeared
}
