//
//  ExportAction.swift
//  TrackList
//
//  Действия пользовательского интерфейса глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import UIKit

/// Описывает действия пользователя и экранов, относящиеся к глобальному экспорту.
enum ExportAction {

    /// Запускает экспорт выбранных треков в папку, выбранную пользователем.
    case start(
        tracks: [Track],
        exportFolder: ExportFolder,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController
    )

    /// Запрашивает отмену текущей операции экспорта.
    case cancel

    /// Открывает подробности текущей операции экспорта.
    case presentDetails

    /// Закрывает подробный экран, сохраняя результат операции.
    case dismissDetails

    /// Сообщает об исчезновении конкретного route подробностей после системного dismiss.
    case detailsDidDisappear(ExportDetailsSheetRoute)

    /// Удаляет завершённый результат из глобального состояния.
    case dismissCompleted
}

/// Принимает типизированные действия Export-feature из SwiftUI-представлений.
@MainActor
protocol ExportActionHandling: AnyObject {

    /// Выполняет пользовательское намерение или lifecycle-событие экспорта.
    func handle(_ action: ExportAction)
}
