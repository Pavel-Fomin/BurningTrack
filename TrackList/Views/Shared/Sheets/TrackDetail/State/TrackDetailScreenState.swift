//
//  TrackDetailScreenState.swift
//  TrackList
//
//  Готовое presentation-состояние временного сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Режим отображения карточки трека.
enum TrackDetailMode: Equatable {
    /// Просмотр актуальных данных трека.
    case view
    /// Редактирование временного черновика.
    case edit
}

/// Единственный системный alert, доступный текущему Track Detail flow.
enum TrackDetailAlert: Equatable {
    /// Файл удерживается текущим воспроизведением.
    case stopPlayback
    /// В папке уже существует файл с целевым именем.
    case fileNameConflict
}

/// Готовое состояние artwork для отображения без мутации domain-состояния во View.
struct TrackDetailArtworkPresentationState: Equatable {
    /// Лёгкий запрос существующему UI-компоненту подготовки preview.
    let request: ArtworkRequest?
    /// Доступно ли добавление новой artwork.
    let canAddArtwork: Bool
    /// Доступно ли удаление существующей или выбранной artwork.
    let canRemoveArtwork: Bool
}

/// Готовое состояние экрана без ссылок на runtime, storage и командные зависимости.
struct TrackDetailScreenState: Equatable {
    /// Текущий режим карточки.
    let mode: TrackDetailMode
    /// Выполняется ли начальная подготовка runtime-данных.
    let isLoading: Bool
    /// Выполняется ли подтверждённая команда сохранения.
    let isSaving: Bool
    /// Доступен ли переход к режиму редактирования для текущего источника.
    let canEnterEdit: Bool
    /// Доступно ли сохранение текущего черновика.
    let canSave: Bool
    /// Редактируемая основа имени файла без расширения.
    let fileName: String
    /// Готовые значения полей редактирования.
    let editableValues: [EditableTrackField: String]
    /// Человекочитаемый путь к папке файла.
    let filePath: String?
    /// Отформатированная техническая информация о файле.
    let technicalInfo: String
    /// Готовое состояние artwork для read-only и edit UI.
    let artwork: TrackDetailArtworkPresentationState
    /// Доступны ли стратегии построения имени из Artist и Title.
    let canUseFileNameStrategies: Bool
    /// Текст локальной ошибки year, если значение невалидно.
    let yearValidationMessage: String?
    /// Текущий системный alert flow.
    let alert: TrackDetailAlert?
}
