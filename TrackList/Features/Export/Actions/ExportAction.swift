//
//  ExportAction.swift
//  TrackList
//
//  Действия пользовательского интерфейса глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import UIKit

/// Описывает действия пользователя и экранов, относящиеся к глобальному экспорту.
enum ExportAction {

    /// Запускает экспорт выбранных треков в папку, выбранную пользователем.
    case start(
        tracks: [Track],
        exportFolderName: String,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController
    )

    /// Запрашивает отмену текущей операции экспорта.
    case cancel

    /// Открывает подробности текущей операции экспорта.
    case presentDetails

    /// Закрывает подробный экран, сохраняя результат операции.
    case dismissDetails

    /// Сообщает о системном закрытии подробного экрана.
    case detailsDidDisappear

    /// Удаляет завершённый результат из глобального состояния.
    case dismissCompleted
}
