//
//  BatchTagEditScreenState.swift
//  TrackList
//
//  Готовое presentation-состояние сценария массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Данные одного поля, полностью подготовленные для Batch Tag Edit View.
struct BatchTagEditFieldScreenState: Identifiable, Equatable {
    /// Семантическое поле редактируемого тега.
    let field: EditableTrackField
    /// Текущее отображаемое значение.
    let value: String
    /// Placeholder для mixed-состояния.
    let placeholder: String
    /// Нужно ли визуально выделить placeholder mixed-поля.
    let emphasizesPlaceholder: Bool
    /// Доступна ли отдельная кнопка очистки mixed-поля.
    let showsClearButton: Bool

    /// Стабильная идентичность строки формы.
    var id: EditableTrackField {
        field
    }
}

/// Готовое состояние summary-карточки artwork.
struct BatchTagEditArtworkSummaryScreenState: Equatable {
    /// Количество выбранных треков.
    let selectedCount: Int
    /// Отформатированный общий размер artwork.
    let formattedArtworkSize: String
    /// Выбрана ли summary-карточка.
    let isSelected: Bool
}

/// Готовое состояние одной artwork-карточки.
struct BatchTagEditArtworkCardScreenState: Identifiable, Equatable {
    /// Идентификатор конкретного трека.
    let trackId: UUID
    /// Подпись карточки.
    let title: String
    /// Лёгкий запрос существующему presentation-компоненту artwork.
    let artworkRequest: ArtworkRequest?
    /// Есть ли artwork с учётом несохранённого draft.
    let hasArtwork: Bool
    /// Отформатированный размер artwork с учётом draft.
    let formattedArtworkSize: String
    /// Выбрана ли карточка.
    let isSelected: Bool

    /// Идентичность SwiftUI-карточки совпадает с физическим треком.
    var id: UUID {
        trackId
    }
}

/// Presentation-состояние секции artwork без service или runtime-ссылок.
struct BatchTagEditArtworkScreenState: Equatable {
    /// Текущая выбранная цель редактирования.
    let selectedTarget: BatchTagArtworkActionTarget?
    /// Готовое состояние summary-карточки.
    let summary: BatchTagEditArtworkSummaryScreenState
    /// Готовые состояния карточек треков.
    let cards: [BatchTagEditArtworkCardScreenState]
    /// Сообщение о частичных ошибках сжатия, если оно нужно UI.
    let compressionFailureText: String?
    /// Прогресс подготовки replacement artwork.
    let preparationProgress: BatchTagArtworkPreparationProgress?
    /// Выполняется ли compression artwork.
    let isCompressing: Bool
}

/// Готовый итог batch-сохранения, который остаётся на экране, пока пользователь не увидит проблемные треки.
struct BatchTagEditSaveSummaryScreenState: Equatable {
    /// Одна понятная пользователю проблема конкретного трека.
    struct Failure: Identifiable, Equatable {
        /// Идентичность совпадает с физическим треком batch-операции.
        let trackId: UUID
        /// Имя трека, подготовленное без обращения View к domain-модели.
        let trackName: String
        /// Понятное описание фактического состояния mutation.
        let message: String

        var id: UUID {
            trackId
        }
    }

    /// Количество треков с подтверждённым новым runtime snapshot.
    let confirmedCount: Int
    /// Ошибки, для которых пользователь должен увидеть состояние каждого трека.
    let failures: [Failure]
}

/// Единственное presentation-состояние Batch Tag Edit без mutable draft и manager-ов.
struct BatchTagEditScreenState: Equatable {
    /// Текущий отображаемый этап feature.
    let phase: BatchTagEditPhase
    /// Доступно ли подтверждение сохранения.
    let canSave: Bool
    /// Поля, подготовленные для выбранной artwork target.
    let displayedFields: [BatchTagEditFieldScreenState]
    /// Готовое состояние artwork-секции.
    let artwork: BatchTagEditArtworkScreenState
    /// Итог последнего partial или failed batch-сохранения, если он требует внимания пользователя.
    let saveSummary: BatchTagEditSaveSummaryScreenState?
}
