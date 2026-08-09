//
//  TrackDetailFlowProtocols.swift
//  TrackList
//
//  Узкие контракты зависимостей временного сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation

/// Предоставляет последний готовый runtime snapshot трека.
@MainActor
protocol TrackDetailSnapshotProviding: AnyObject {
    /// Возвращает snapshot без повторного чтения файла.
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot?
}

/// Собирает runtime snapshot для локального или purchased iTunes источника.
protocol TrackDetailSnapshotBuilding: AnyObject {
    /// Собирает snapshot локального файлового трека.
    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot?
    /// Собирает snapshot purchased iTunes-трека без bookmark pipeline.
    func buildSnapshot(
        forPurchasedITunesTrack track: PurchasedITunesPlayableTrack
    ) async -> TrackRuntimeSnapshot
}

/// Резолвит URL файлового трека только для presentation пути.
protocol TrackDetailFileURLResolving {
    /// Возвращает текущий URL локального трека через существующий bookmark pipeline.
    func fileURL(forTrackId trackId: UUID) async -> URL?
}

/// Выполняет существующую атомарную команду сохранения изменений трека.
protocol TrackDetailCommandExecuting {
    /// Сохраняет имя файла, теги и artwork через общий command pipeline.
    func saveTrackEdits(
        trackId: UUID,
        newFileName: String,
        fileChanged: Bool,
        patch: TagWritePatch,
        tagsChanged: Bool,
        artworkAction: ArtworkWriteAction,
        artworkChanged: Bool,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackEditsSavedSuccess
}

/// Закрывает только активный Track Detail flow через общий lifecycle sheet-ов.
@MainActor
protocol TrackDetailRouting: AnyObject {
    /// Закрывает только route карточки трека с переданной идентичностью.
    func dismissTrackDetail(_ routeID: UUID)
}

/// Передаёт готовые события обновления runtime-данных выбранного трека.
@MainActor
protocol TrackDetailEventProviding {
    /// Единый поток обновления одного трека.
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> { get }
}

// MARK: - Production adapters

extension TrackRuntimeStore: TrackDetailSnapshotProviding {}

extension TrackRuntimeSnapshotBuilder: TrackDetailSnapshotBuilding {}

/// Адаптирует существующий статический BookmarkResolver к feature-local контракту.
struct BookmarkTrackDetailFileURLResolver: TrackDetailFileURLResolving {
    func fileURL(forTrackId trackId: UUID) async -> URL? {
        await BookmarkResolver.url(forTrack: trackId)
    }
}

extension AppCommandExecutor: TrackDetailCommandExecuting {}

extension SheetManager: TrackDetailRouting {}

/// Адаптирует существующий TrackUpdateCoordinator transport без создания нового event bus.
@MainActor
struct NotificationTrackDetailEventProvider: TrackDetailEventProviding {
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        NotificationCenter.default.publisher(for: .trackDidUpdate)
            .compactMap { $0.object as? TrackUpdateEvent }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
