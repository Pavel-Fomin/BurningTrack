//
//  ExportDestination.swift
//  TrackList
//
//  Модель выбранной пользователем папки назначения экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Описывает папку, в которую сервис должен записать экспортированные файлы.
///
/// URL сохраняется как URL файлового провайдера, а не преобразуется в локальный
/// путь. Это позволяет одинаково работать с iCloud Drive, USB и другими
/// расположениями, доступными через приложение «Файлы».
struct ExportDestination: Equatable, Sendable {

    /// URL папки, полученный от UIDocumentPickerViewController.
    let folderURL: URL

    /// Безопасное короткое имя папки для будущего отображения в интерфейсе.
    let displayName: String

    /// Создаёт модель назначения из URL выбранной папки.
    init(folderURL: URL) {
        self.folderURL = folderURL

        let lastPathComponent = folderURL.lastPathComponent
        self.displayName = lastPathComponent.isEmpty
            ? folderURL.absoluteString
            : lastPathComponent
    }
}
