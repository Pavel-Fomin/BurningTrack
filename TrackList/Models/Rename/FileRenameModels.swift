//
//  FileRenameModels.swift
//  TrackList
//
//  Доменные модели для подготовки будущего переименования файлов треков.
//  Описывает данные, стратегии и состояния переименования без UI и без физической работы с файловой системой.
//
//  Created by Pavel Fomin on 16.05.2026.
//

import Foundation

/// Стратегия формирования нового имени файла трека.
enum FileRenameStrategy: Equatable {
    /// Имя файла строится в формате "исполнитель - название".
    case artistTitle

    /// Имя файла строится в формате "название - исполнитель".
    case titleArtist

    /// Имя файла задано пользователем вручную.
    case manual
}

/// Причина, по которой предложение переименования нельзя применить.
enum FileRenameSkipReason: Equatable {
    case tagsMissing
    case emptyFileName
    case invalidFileName
    case unchangedFileName
}

/// Текущее состояние предложения по переименованию файла.
enum FileRenameStatus: Equatable {
    /// Предложение создано, но еще не проверено.
    case pending

    /// Предложение готово к применению.
    case ready

    /// Предложение пропущено по semantic причине.
    case skipped(reason: FileRenameSkipReason)

    /// Переименование завершилось ошибкой.
    case failed

    /// Переименование успешно применено.
    case applied
}

/// Предложение по переименованию одного файла трека.
struct FileRenameProposal: Identifiable, Equatable {
    /// Уникальный идентификатор предложения.
    let id: UUID

    /// Идентификатор трека, к которому относится предложение.
    let trackId: UUID

    /// Текущее имя файла до переименования.
    let oldFileName: String

    /// Новое имя файла, подготовленное выбранной стратегией.
    let newFileName: String

    /// Стратегия, по которой сформировано новое имя файла.
    let strategy: FileRenameStrategy

    /// Состояние предложения по переименованию.
    let status: FileRenameStatus

    /// Создает предложение по переименованию файла трека.
    init(
        id: UUID = UUID(),
        trackId: UUID,
        oldFileName: String,
        newFileName: String,
        strategy: FileRenameStrategy,
        status: FileRenameStatus
    ) {
        self.id = id
        self.trackId = trackId
        self.oldFileName = oldFileName
        self.newFileName = newFileName
        self.strategy = strategy
        self.status = status
    }
}

/// Входные данные для построения предложения по переименованию файла.
struct FileRenameInput: Equatable {
    /// Идентификатор трека, для которого готовится переименование.
    let trackId: UUID

    /// Текущее имя файла трека.
    let currentFileName: String

    /// Исполнитель из метаданных трека.
    let artist: String?

    /// Название из метаданных трека.
    let title: String?

    /// Проверяет, достаточно ли тегов для автоматического формирования имени файла.
    var hasUsableTags: Bool {
        let artistValue = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let titleValue = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !artistValue.isEmpty && !titleValue.isEmpty
    }
}
