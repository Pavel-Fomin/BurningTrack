//
//  ExportAction.swift
//  TrackList
//
//  Действия пользовательского интерфейса глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

/// Описывает действия собственного пользовательского интерфейса Export-feature.
enum ExportAction {

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
