//
//  TagLibTagsWriter.swift
//  TrackList
//
//  Swift-реализация записи тегов поверх Obj-C обёртки TagLib.
//  Отвечает ТОЛЬКО за мост Swift ↔ Obj-C и маппинг ошибок.
//
//  Created by PavelFomin on 16.01.2026.
//

import Foundation

final class TagLibTagsWriter: TagsWriter {

    // MARK: - Init

    init() {}

    // MARK: - TagsWriter

    func writeTags(
        to url: URL,
        patch: TagWritePatch
    ) async throws {

        // Obj-C ожидает filePath
        let path = url.path
        
        let artworkAction: TLArtworkAction
        let artworkData: Data?
        let artworkMime: String?

        switch patch.artwork {
        case .none:
            artworkAction = .none
            artworkData = nil
            artworkMime = nil

        case .remove:
            artworkAction = .remove
            artworkData = nil
            artworkMime = nil

        case .set(let data, let mime):
            artworkAction = .set
            artworkData = data
            artworkMime = mime

        case .setCompressed(let data, let mime, _, _):
            // Сжатие будет добавлено позже
            artworkAction = .set
            artworkData = data
            artworkMime = mime
        }

        // Вызов Obj-C write-функции
        let result = _writeBasicTags(
            path,
            patch.title,
            patch.artist,
            patch.album,
            patch.genre,
            patch.comment,
            patch.year.map { NSNumber(value: $0) },
            patch.trackNumber.map { NSNumber(value: $0) },
            patch.bpm.map { NSNumber(value: $0) },
            artworkAction,
            artworkData,
            artworkMime
        )
        
        // Маппинг результата
        switch result.status {

        case .ok:
            return

        case .fileNotFound:
            throw TagWriteError.fileNotFound

        case .fileNotWritable:
            throw TagWriteError.fileNotWritable

        case .unsupportedFormat:
            throw TagWriteError.unsupportedFormat

        case .saveFailed:
            throw TagWriteError.saveFailed(details: result.details)

        case .unknown:
            fallthrough

        @unknown default:
            throw TagWriteError.unknown(details: result.details)
        }
    }
}
