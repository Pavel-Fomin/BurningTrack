//
//  CloudTrackAvailabilityManager.swift
//  TrackList
//
//  Компонент определения и запроса загрузки iCloud-файлов.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Контракт работы с runtime-состоянием iCloud-файлов треков.
protocol CloudTrackAvailabilityManaging: Sendable {
    /// Возвращает достоверно определённые состояния для переданных треков.
    func availabilityStates(
        for trackIds: [UUID]
    ) async -> [UUID: CloudTrackAvailabilityState]

    /// Повторно запрашивает загрузку iCloud-файла после ошибки.
    func retryDownloading(
        trackId: UUID
    ) async -> CloudTrackAvailabilityState?
}

/// Изолированно работает с URL resource values и системным API загрузки iCloud.
actor CloudTrackAvailabilityManager: CloudTrackAvailabilityManaging {

    // MARK: - Singleton

    /// Общий компонент для всех мест, которым понадобится runtime-состояние iCloud-файла.
    static let shared = CloudTrackAvailabilityManager()

    // MARK: - Init

    private init() {}

    // MARK: - Состояние

    /// Возвращает состояния только тех треков, для которых iCloud-состояние удалось определить.
    func availabilityStates(
        for trackIds: [UUID]
    ) async -> [UUID: CloudTrackAvailabilityState] {
        var statesByTrackId: [UUID: CloudTrackAvailabilityState] = [:]
        statesByTrackId.reserveCapacity(trackIds.count)

        for trackId in trackIds {
            // Отмена экрана не должна продолжать файловые проверки уже неактуального списка.
            guard Task.isCancelled == false else {
                return statesByTrackId
            }

            guard let state = await availabilityState(for: trackId) else {
                continue
            }

            statesByTrackId[trackId] = state
        }

        return statesByTrackId
    }

    /// Повторно передаёт системе запрос на загрузку файла и возвращает новое состояние строки.
    func retryDownloading(
        trackId: UUID
    ) async -> CloudTrackAvailabilityState? {
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return nil
        }

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            return .downloadFailed
        }

        // После успешного запроса отображаем ожидание загрузки даже до обновления resource values.
        switch state(for: url) {
        case .local:
            return .local
        case .downloadFailed:
            return .downloadFailed
        case .notDownloaded,
             .downloading,
             .none:
            return .downloading
        }
    }

    /// Определяет состояние файла по URL, восстановленному существующим bookmark-пайплайном.
    private func availabilityState(
        for trackId: UUID
    ) async -> CloudTrackAvailabilityState? {
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return nil
        }

        return state(for: url)
    }

    /// Преобразует системные resource values в прикладное состояние доступности трека.
    private func state(
        for url: URL
    ) -> CloudTrackAvailabilityState? {
        let resourceKeys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemDownloadingErrorKey
        ]

        guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
            // Не скрываем меню, если система не смогла достоверно описать обычный локальный файл.
            return nil
        }

        guard values.isUbiquitousItem == true else {
            return .local
        }

        if values.ubiquitousItemIsDownloading == true {
            return .downloading
        }

        let downloadingStatus = values.ubiquitousItemDownloadingStatus
        if downloadingStatus == .current || downloadingStatus == .downloaded {
            return .local
        }

        if values.ubiquitousItemDownloadingError != nil {
            return .downloadFailed
        }

        if downloadingStatus == .notDownloaded {
            return .notDownloaded
        }

        // Неполные resource values не должны ошибочно блокировать локальные действия пользователя.
        return nil
    }
}
