//
//  BatchTagEditSavePlanner.swift
//  TrackList
//
//  Planner массового сохранения тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Planner массового сохранения тегов.
///
/// Роль:
/// - преобразует BatchTagEditFlow в команды записи;
/// - не пишет файлы;
/// - не обращается к TagLib;
/// - не знает про UI и SheetManager.
enum BatchTagEditSavePlanner {
    /// Создаёт план массового сохранения тегов.
    static func makePlan(
        from flow: BatchTagEditFlow
    ) throws -> BatchTagEditSavePlan {
        let groupPatch = try makePatch(from: flow.fields)
        let commands: [BatchTagEditWriteCommand] = try flow.tracks.compactMap { track in
            let overrideFields = flow.trackFieldOverrides[track.trackId]?.fields.values.map { $0 } ?? []
            let overridePatch = try makePatch(from: overrideFields)
            let patch = mergedPatch(
                groupPatch: groupPatch,
                overridePatch: overridePatch
            )
            let artworkEditAction = flow.artwork.action(for: track.trackId)
            let artworkAction = try makeArtworkAction(
                from: artworkEditAction,
                newArtworkData: flow.artwork.newArtworkData
            )
            guard hasChanges(
                patch: patch,
                artworkAction: artworkAction
            ) else {
                return nil
            }
            return BatchTagEditWriteCommand(
                trackId: track.trackId,
                patch: patch,
                artworkAction: artworkAction
            )
        }
        return BatchTagEditSavePlan(commands: commands)
    }

    /// Собирает patch текстовых тегов.
    private static func makePatch(
        from fields: [BatchTagFieldEditState]
    ) throws -> TagWritePatch {
        var patch = TagWritePatch()
        for fieldState in fields {
            try apply(fieldState, to: &patch)
        }
        return patch
    }

    /// Объединяет общий patch и patch конкретного трека.
    /// Per-track override имеет приоритет над group-level изменением.
    private static func mergedPatch(
        groupPatch: TagWritePatch,
        overridePatch: TagWritePatch
    ) -> TagWritePatch {
        var patch = groupPatch
        if overridePatch.title != .unchanged {
            patch.title = overridePatch.title
        }
        if overridePatch.artist != .unchanged {
            patch.artist = overridePatch.artist
        }
        if overridePatch.album != .unchanged {
            patch.album = overridePatch.album
        }
        if overridePatch.publisher != .unchanged {
            patch.publisher = overridePatch.publisher
        }
        if overridePatch.genre != .unchanged {
            patch.genre = overridePatch.genre
        }
        if overridePatch.comment != .unchanged {
            patch.comment = overridePatch.comment
        }
        if overridePatch.year != .unchanged {
            patch.year = overridePatch.year
        }
        return patch
    }

    /// Есть ли реальные изменения в команде записи.
    private static func hasChanges(
        patch: TagWritePatch,
        artworkAction: ArtworkWriteAction
    ) -> Bool {
        if artworkAction != .none {
            return true
        }
        return patch.title != .unchanged
            || patch.artist != .unchanged
            || patch.album != .unchanged
            || patch.publisher != .unchanged
            || patch.genre != .unchanged
            || patch.comment != .unchanged
            || patch.year != .unchanged
    }

    /// Применяет состояние одного поля к patch.
    private static func apply(
        _ fieldState: BatchTagFieldEditState,
        to patch: inout TagWritePatch
    ) throws {
        switch fieldState.field {
        case .title:
            patch.title = stringChange(from: fieldState)
        case .artist:
            patch.artist = stringChange(from: fieldState)
        case .album:
            patch.album = stringChange(from: fieldState)
        case .genre:
            patch.genre = stringChange(from: fieldState)
        case .publisher:
            patch.publisher = stringChange(from: fieldState)
        case .comment:
            patch.comment = stringChange(from: fieldState)
        case .year:
            patch.year = try yearChange(from: fieldState)
        }
    }

    /// Собирает изменение строкового поля.
    private static func stringChange(
        from fieldState: BatchTagFieldEditState
    ) -> TagFieldChange<String> {
        let value = fieldState.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch fieldState.action {
        case .keep:
            return .unchanged
        case .set:
            return value.isEmpty ? .clear : .set(value)
        case .clear:
            return .clear
        }
    }

    /// Собирает изменение поля года.
    private static func yearChange(
        from fieldState: BatchTagFieldEditState
    ) throws -> TagFieldChange<Int> {
        let value = fieldState.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch fieldState.action {
        case .keep:
            return .unchanged
        case .clear:
            return .clear
        case .set:
            guard !value.isEmpty else {
                return .clear
            }
            guard let year = Int(value) else {
                throw BatchTagEditSaveValidationError.invalidYear(value)
            }
            return .set(year)
        }
    }

    /// Собирает действие с обложкой.
    private static func makeArtworkAction(
        from action: BatchTagArtworkEditAction,
        newArtworkData: Data?
    ) throws -> ArtworkWriteAction {
        switch action {
        case .keep:
            return .none
        case .remove:
            return .remove
        case .replace:
            guard let newArtworkData else {
                throw BatchTagEditSaveValidationError.missingReplacementArtwork
            }
            return .replace(data: newArtworkData)
        }
    }
}
