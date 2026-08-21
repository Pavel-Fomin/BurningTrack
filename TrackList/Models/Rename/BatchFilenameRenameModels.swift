//
//  BatchFilenameRenameModels.swift
//  TrackList
//
//  Неизменяемые модели массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Определяет порядок artist и title в новом имени файла.
enum FilenameRenameStrategy: Equatable {
    /// Имя файла строится в формате "исполнитель - название".
    case artistTitle

    /// Имя файла строится в формате "название - исполнитель".
    case titleArtist
}

/// Сохраняет полный результат подготовки или применения одной строки batch-операции.
enum BatchFilenameRenameStatus: Equatable {
    /// Элемент готов для будущего применения.
    case ready
    /// Файл успешно переименован.
    case renamed
    /// В метаданных нет исполнителя.
    case missingArtist
    /// В метаданных нет названия.
    case missingTitle
    /// В метаданных нет исполнителя и названия.
    case missingArtistAndTitle
    /// Целевое имя не удалось собрать в допустимое имя файла.
    case invalidTargetName
    /// Файл не удалось переименовать.
    case applyFailed
    /// Файл сейчас используется плеером.
    case trackIsPlaying
    /// Нет доступа к файлу или папке.
    case fileAccessDenied
}

/// Отображаемый этап feature-local сессии массового переименования.
enum BatchFilenameRenamePhase: Equatable {
    /// Metadata выбранных файлов загружается, а sheet уже показывает исходные имена.
    case loadingMetadata
    /// Пользователь просматривает и корректирует подготовленный план.
    case preparing
    /// Переименование уже применялось хотя бы один раз.
    case applied
}

/// Неизменяемый снимок строки Library, достаточный для немедленного открытия sheet.
struct BatchFilenameRenameTrackSeed: Equatable {
    /// Идентификатор трека из TrackRegistry.
    let trackId: UUID
    /// Путь родительской папки нужен для уникальности имён внутри одной папки.
    let folderPath: String
    /// Текущее имя файла с исходным расширением.
    let currentFileName: String
    /// Fallback-исполнитель из уже отображённой Library.
    let artist: String?
    /// Fallback-название из уже отображённой Library.
    let title: String?
}

/// Подготовленные данные трека после попытки загрузить runtime metadata.
struct BatchFilenameRenameTrack: Equatable {
    /// Идентификатор трека из TrackRegistry.
    let trackId: UUID
    /// Путь родительской папки исходного файла.
    let folderPath: String
    /// Текущее имя файла с исходным расширением.
    let currentFileName: String
    /// Исполнитель из runtime snapshot либо fallback Library.
    let artist: String?
    /// Название из runtime snapshot либо fallback Library.
    let title: String?

    /// Создаёт начальные данные до завершения runtime metadata loading.
    init(seed: BatchFilenameRenameTrackSeed) {
        trackId = seed.trackId
        folderPath = seed.folderPath
        currentFileName = seed.currentFileName
        artist = seed.artist
        title = seed.title
    }

    /// Объединяет snapshot с исходным route, не теряя fallback Library при ошибке чтения.
    init(
        seed: BatchFilenameRenameTrackSeed,
        snapshot: TrackRuntimeSnapshot?
    ) {
        trackId = seed.trackId
        folderPath = seed.folderPath
        currentFileName = seed.currentFileName
        artist = snapshot?.artist ?? seed.artist
        title = snapshot?.title ?? seed.title
    }
}

/// Одна строка готового плана с сохранением исходного расширения и статуса операции.
struct BatchFilenameRenameItem: Identifiable, Equatable {
    /// Идентичность строки совпадает с идентификатором трека.
    var id: UUID { trackId }
    /// Идентификатор трека из TrackRegistry.
    let trackId: UUID
    /// Путь родительской папки исходного файла.
    let folderPath: String
    /// Текущее имя файла с исходным расширением.
    let currentFileName: String
    /// Новое имя файла с сохранённым исходным расширением.
    let targetFileName: String
    /// Исполнитель, использованный при построении плана.
    let artist: String?
    /// Название, использованное при построении плана.
    let title: String?
    /// Стратегия, по которой построено целевое имя.
    let strategy: FilenameRenameStrategy?
    /// Статус элемента плана.
    var status: BatchFilenameRenameStatus
    /// Сохраняет исходную семантику failed mutation до формирования текста строки в Presenter.
    let mutationFailure: MutationFailure?

    /// Возвращает копию элемента с новым статусом без мутации domain-модели.
    func withStatus(_ newStatus: BatchFilenameRenameStatus) -> BatchFilenameRenameItem {
        BatchFilenameRenameItem(
            trackId: trackId,
            folderPath: folderPath,
            currentFileName: currentFileName,
            targetFileName: targetFileName,
            artist: artist,
            title: title,
            strategy: strategy,
            status: newStatus,
            mutationFailure: nil
        )
    }

    /// Возвращает failed-строку, не подменяя технической меткой фактическое состояние mutation.
    func withMutationFailure(
        _ failure: MutationFailure,
        status: BatchFilenameRenameStatus
    ) -> BatchFilenameRenameItem {
        BatchFilenameRenameItem(
            trackId: trackId,
            folderPath: folderPath,
            currentFileName: currentFileName,
            targetFileName: targetFileName,
            artist: artist,
            title: title,
            strategy: strategy,
            status: status,
            mutationFailure: failure
        )
    }
}
