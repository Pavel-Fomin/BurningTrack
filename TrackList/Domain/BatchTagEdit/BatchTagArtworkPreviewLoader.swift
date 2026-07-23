//
//  BatchTagArtworkPreviewLoader.swift
//  TrackList
//
//  Loader preview-обложек для массового редактирования тегов.
//
//  Created by Pavel Fomin on 04.06.2026.
//

import Foundation
import UIKit

/// Лениво загружает thumbnail обложки для preview-карточек массового редактирования тегов.
actor BatchTagArtworkPreviewLoader {
    static let shared = BatchTagArtworkPreviewLoader()

    private init() {}

    /// Возвращает маленькую preview-обложку трека.
    ///
    /// Loader не хранит raw Data: данные берутся из runtime/cache слоёв и сразу передаются в ArtworkProvider.
    ///
    /// - Parameters:
    ///   - trackId: Идентификатор трека.
    ///   - hasArtwork: Признак наличия обложки из preview-модели.
    /// - Returns: Готовая UIImage для preview или nil, если обложки нет либо загрузка отменена.
    func image(forTrackId trackId: UUID, hasArtwork: Bool) async -> UIImage? {
        guard hasArtwork else { return nil }

        if let snapshot = await TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
            guard Task.isCancelled == false else { return nil }
            return await makePreviewImage(
                trackId: trackId,
                artworkData: snapshot.artworkData,
                sourceIdentifier: snapshot.artworkSourceIdentifier,
                revision: snapshot.updatedAt
            )
        }

        guard Task.isCancelled == false else { return nil }

        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return nil
        }

        guard Task.isCancelled == false else { return nil }

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: url) else {
            return nil
        }

        guard Task.isCancelled == false else { return nil }

        return await makePreviewImage(
            trackId: trackId,
            artworkData: metadata.artworkData,
            sourceIdentifier: metadata.artworkSourceIdentifier,
            revision: nil
        )
    }

    /// Сбрасывает подготовленную обложку одного трека во внутреннем ArtworkProvider.
    func invalidate(trackId: UUID) async {
        await ArtworkProvider.shared.invalidate(trackId: trackId)
    }

    /// Полностью очищает кэш подготовленных preview-обложек.
    func removeAll() async {
        await ArtworkProvider.shared.removeAll()
    }

    /// Создаёт downsampled preview-изображение через общий ArtworkProvider.
    private func makePreviewImage(
        trackId: UUID,
        artworkData: Data?,
        sourceIdentifier: ArtworkSourceIdentifier?,
        revision: Date?
    ) async -> UIImage? {
        guard let sourceIdentifier else { return nil }

        return await ArtworkProvider.shared.image(
            for: ArtworkRequest(
                trackId: trackId,
                artworkData: artworkData,
                purpose: .batchTagPreview,
                sourceIdentifier: sourceIdentifier,
                revision: revision
            )
        )
    }
}
