//
//  TrackCollectionSummary.swift
//  TrackList
//
//  Общая статистика содержимого папки фонотеки или треклиста.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Агрегированная статистика коллекции треков, полученная из сохранённых данных SQLite.
/// Счётчики неизвестных значений позволяют не показывать пользователю неполную сумму.
struct TrackCollectionSummary: Equatable, Sendable {
    /// Количество строк коллекции: для треклиста учитываются повторные добавления одного трека.
    let trackCount: Int
    /// Суммарная известная длительность в секундах.
    let totalDuration: TimeInterval?
    /// Суммарный известный размер файлов в байтах.
    let totalFileSize: Int64?
    /// Число строк без сохранённой длительности.
    let unknownDurationCount: Int
    /// Число строк без сохранённого размера файла.
    let unknownFileSizeCount: Int

    /// Показывает, что длительность известна для каждой строки коллекции.
    var hasCompleteDuration: Bool {
        unknownDurationCount == 0
    }

    /// Показывает, что размер файла известен для каждой строки коллекции.
    var hasCompleteFileSize: Bool {
        unknownFileSizeCount == 0
    }
}

/// Предоставляет статистику папки фонотеки и треклиста независимо от UI и менеджеров.
protocol TrackCollectionSummaryProviding: Sendable {
    /// Возвращает статистику треков, непосредственно сохранённых в указанной папке.
    func summaryForFolder(folderId: UUID) async throws -> TrackCollectionSummary

    /// Возвращает статистику строк указанного треклиста.
    func summaryForTrackList(trackListId: UUID) async throws -> TrackCollectionSummary
}
