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
    
    // MARK: - Mapping

    /// Возвращает действие для строкового тега.
    private func stringAction(
        _ change: TagFieldChange<String>
    ) -> TLTagFieldAction {
        switch change {
        case .unchanged:
            return .unchanged
        case .set:
            return .set
        case .clear:
            return .clear
        }
    }

    /// Возвращает значение для строкового тега.
    /// Для unchanged и clear само значение не нужно.
    private func stringValue(
        _ change: TagFieldChange<String>
    ) -> String? {
        switch change {
        case .unchanged:
            return nil
        case .set(let value):
            return value
        case .clear:
            return nil
        }
    }

    /// Возвращает действие для числового тега.
    private func intAction(
        _ change: TagFieldChange<Int>
    ) -> TLTagFieldAction {
        switch change {
        case .unchanged:
            return .unchanged
        case .set:
            return .set
        case .clear:
            return .clear
        }
    }

    /// Возвращает значение для числового тега.
    /// Для unchanged и clear само значение не нужно.
    private func intValue(
        _ change: TagFieldChange<Int>
    ) -> NSNumber? {
        switch change {
        case .unchanged:
            return nil
        case .set(let value):
            return NSNumber(value: value)
        case .clear:
            return nil
        }
    }

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

            stringAction(patch.title),
            stringValue(patch.title),

            stringAction(patch.artist),
            stringValue(patch.artist),

            stringAction(patch.album),
            stringValue(patch.album),

            stringAction(patch.genre),
            stringValue(patch.genre),

            stringAction(patch.comment),
            stringValue(patch.comment),

            stringAction(patch.publisher),
            stringValue(patch.publisher),

            intAction(patch.year),
            intValue(patch.year),

            intAction(patch.trackNumber),
            intValue(patch.trackNumber),

            intAction(patch.bpm),
            intValue(patch.bpm),

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
