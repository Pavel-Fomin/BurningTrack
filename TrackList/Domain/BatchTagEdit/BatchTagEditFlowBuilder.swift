//
//  BatchTagEditFlowBuilder.swift
//  TrackList
//
//  Builder flow массового редактирования тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Builder flow массового редактирования тегов.
///
/// Роль:
/// - преобразует runtime snapshot выбранных треков в BatchTagEditFlow;
/// - агрегирует одинаковые, пустые и разные значения тегов;
/// - собирает данные preview для обложек;
/// - не читает файлы и не обращается к TagLib.
enum BatchTagEditFlowBuilder {
    /// Собирает flow массового редактирования тегов.
    static func makeFlow(
        pendingAction: PendingBulkTrackAction,
        snapshots: [TrackRuntimeSnapshot]
    ) -> BatchTagEditFlow {
        let orderedSnapshots = orderedSnapshots(
            snapshots,
            trackIDs: pendingAction.trackIDs
        )
        let tracks = makeTracks(from: orderedSnapshots)
        return BatchTagEditFlow(
            pendingAction: pendingAction,
            phase: .editing,
            tracks: tracks,
            fields: makeFieldStates(tracks: tracks),
            trackFieldOverrides: [:],
            artwork: makeArtworkState(snapshots: orderedSnapshots)
        )
    }
    /// Упорядочивает snapshots согласно порядку выбранных track id.
    private static func orderedSnapshots(
        _ snapshots: [TrackRuntimeSnapshot],
        trackIDs: [UUID]
    ) -> [TrackRuntimeSnapshot] {
        let snapshotsById = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.trackId, $0) })
        return trackIDs.compactMap { trackID in
            snapshotsById[trackID]
        }
    }
    /// Собирает batch-модели выбранных треков.
    private static func makeTracks(from snapshots: [TrackRuntimeSnapshot]) -> [BatchTagEditTrack] {
        snapshots.map { snapshot in
            BatchTagEditTrack(
                trackId: snapshot.trackId,
                fileName: snapshot.fileName,
                values: values(from: snapshot),
                hasArtwork: snapshot.artworkData != nil
            )
        }
    }
    /// Собирает значения редактируемых полей из runtime snapshot.
    private static func values(from snapshot: TrackRuntimeSnapshot) -> [EditableTrackField: String] {
        [
            .title: snapshot.title ?? "",
            .artist: snapshot.artist ?? "",
            .album: snapshot.album ?? "",
            .genre: snapshot.genre ?? "",
            .year: snapshot.year.map(String.init) ?? "",
            .publisher: snapshot.publisherOrLabel ?? "",
            .comment: snapshot.comment ?? ""
        ]
    }
    /// Собирает состояния редактируемых полей.
    private static func makeFieldStates(tracks: [BatchTagEditTrack]) -> [BatchTagFieldEditState] {
        EditableTrackField.allCases.map { field in
            let fieldSummary = summary(for: field, tracks: tracks)
            return BatchTagFieldEditState(
                field: field,
                action: .keep,
                value: initialValue(for: fieldSummary),
                summary: fieldSummary
            )
        }
    }

    /// Начальное значение input-поля.
    private static func initialValue(for summary: BatchTagFieldSummary) -> String {
        switch summary {
        case .same(let value):
            return value
        case .empty, .mixed:
            return ""
        }
    }

    /// Считает сводное состояние одного поля среди выбранных треков.
    private static func summary(
        for field: EditableTrackField,
        tracks: [BatchTagEditTrack]
    ) -> BatchTagFieldSummary {
        let values = tracks.map { $0.values[field] ?? "" }
        if values.allSatisfy({ $0.isEmpty }) {
            return .empty
        }
        guard let firstValue = values.first else {
            return .empty
        }
        if !firstValue.isEmpty && values.allSatisfy({ $0 == firstValue }) {
            return .same(firstValue)
        }
        return .mixed
    }
    /// Собирает состояние секции обложек.
    private static func makeArtworkState(snapshots: [TrackRuntimeSnapshot]) -> BatchTagArtworkEditState {
        BatchTagArtworkEditState(
            action: .keep,
            newArtworkData: nil,
            summary: makeArtworkSummary(snapshots: snapshots),
            previewSummary: makeArtworkPreviewSummary(snapshots: snapshots),
            previewItems: makeArtworkPreviewItems(snapshots: snapshots),
            selectedTarget: .summary
        )
    }
    /// Считает общее состояние обложек.
    private static func makeArtworkSummary(snapshots: [TrackRuntimeSnapshot]) -> BatchTagArtworkSummary {
        let artworkItems = snapshots.compactMap(\.artworkData)
        if artworkItems.isEmpty {
            return .none
        }
        if artworkItems.count != snapshots.count {
            return .mixed
        }
        guard let firstArtwork = artworkItems.first else {
            return .none
        }
        return artworkItems.allSatisfy { $0 == firstArtwork } ? .same : .mixed
    }
    /// Считает summary для первой карточки preview.
    private static func makeArtworkPreviewSummary(snapshots: [TrackRuntimeSnapshot]) -> BatchTagArtworkPreviewSummary {
        let artworkCount = snapshots.filter { $0.artworkData != nil }.count
        return BatchTagArtworkPreviewSummary(
            selectedCount: snapshots.count,
            artworkCount: artworkCount,
            missingArtworkCount: snapshots.count - artworkCount
        )
    }
    /// Собирает preview items для всех выбранных треков.
    private static func makeArtworkPreviewItems(snapshots: [TrackRuntimeSnapshot]) -> [BatchTagArtworkPreviewItem] {
        snapshots.map { snapshot in
            BatchTagArtworkPreviewItem(
                id: snapshot.trackId,
                trackId: snapshot.trackId,
                title: snapshot.fileName,
                hasArtwork: snapshot.artworkData != nil
            )
        }
    }
}
