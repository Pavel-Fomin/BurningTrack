//
//  BatchFilenameRenameScreenState.swift
//  TrackList
//
//  Готовое presentation-состояние массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Счётчик progress, готовый для отображения без доступа View к domain-драфту.
struct BatchFilenameRenameProgress: Equatable {
    /// Количество уже обработанных строк.
    let processedCount: Int
    /// Общее количество строк текущей операции.
    let totalCount: Int
}

/// Визуальный стиль подписи статуса строки массового переименования.
enum BatchFilenameRenameRowStatusStyle: Equatable {
    /// У строки нет итогового статуса.
    case neutral
    /// Строка успешно переименована.
    case success
    /// Строка содержит ошибку metadata или применения.
    case error
}

/// Единственный immutable снимок UI Batch Filename Rename без manager-ов и domain-моделей.
struct BatchFilenameRenameScreenState: Equatable {
    /// Готовая строка списка файлов.
    struct Row: Identifiable, Equatable {
        /// Идентичность строки совпадает с идентификатором трека.
        let trackId: UUID
        /// Имя файла, подготовленное для отображения.
        let fileName: String
        /// Готовый локализованный статус строки, если он нужен.
        let statusDescription: String?
        /// Визуальный стиль статуса.
        let statusStyle: BatchFilenameRenameRowStatusStyle

        var id: UUID { trackId }
    }

    /// Строки выбранных файлов либо подготовленного плана.
    let rows: [Row]
    /// Выбранная стратегия формирования имени.
    let selectedStrategy: FilenameRenameStrategy?
    /// Готовый текст выбранной стратегии.
    let selectedStrategyTitle: String
    /// Выполняется чтение metadata.
    let isLoadingMetadata: Bool
    /// Выполняется физическое переименование файлов.
    let isApplyingRename: Bool
    /// Feature выполняет критическую операцию.
    let isBusy: Bool
    /// Доступно ли применение текущего preview.
    let canApplyRename: Bool
    /// Доступен ли выбор стратегии.
    let canSelectStrategy: Bool
    /// Доступно ли исключение строк из текущей операции.
    let canRemoveTracks: Bool
    /// Нужно ли блокировать interactive dismiss.
    let isDismissDisabled: Bool
    /// Progress подготовки metadata.
    let preparationProgress: BatchFilenameRenameProgress?
    /// Progress физического переименования.
    let applyingProgress: BatchFilenameRenameProgress?
}
