//
//  TrackListScreenStateBuilder.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Собирает состояние экрана одного треклиста.
/// Builder готовит данные для View, чтобы View не читала менеджеры и ViewModel напрямую.
@MainActor
struct TrackListScreenStateBuilder {

    /// Builder состояния строки.
    private let rowStateBuilder: TrackListRowStateBuilder

    /// Создаёт builder состояния экрана с builder'ом строки по умолчанию.
    init() {
        rowStateBuilder = TrackListRowStateBuilder()
    }

    /// Создаёт builder состояния экрана.
    ///
    /// - Parameter rowStateBuilder: Builder состояния строки.
    init(
        rowStateBuilder: TrackListRowStateBuilder
    ) {
        self.rowStateBuilder = rowStateBuilder
    }

    /// Собирает состояние экрана одного треклиста.
    ///
    /// - Parameters:
    ///   - id: Идентификатор треклиста.
    ///   - title: Название треклиста.
    ///   - summary: Семантическая статистика для преобразования во View.
    ///   - tracks: Треки треклиста.
    ///   - snapshotsByTrackId: Runtime snapshots треков по физическому id трека.
    ///   - currentTrackId: Идентификатор текущего TrackDisplayable; для Track это id строки треклиста.
    ///   - currentContext: Контекст текущего воспроизведения.
    ///   - isPlaying: Идёт ли воспроизведение.
    ///   - highlightedRowId: Идентификатор подсвеченной строки.
    ///   - settings: Снимок настроек отображения строк.
    /// - Returns: Готовое состояние экрана.
    func build(
        id: UUID,
        title: String,
        summary: TrackCollectionSummary?,
        tracks: [Track],
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        currentTrackId: UUID?,
        currentContext: PlaybackContext?,
        isPlaying: Bool,
        highlightedRowId: UUID?,
        settings: AppSettings,
        collectionNavigationTargetsByTrackId: [UUID: TrackCollectionNavigationTarget]
    ) -> TrackListScreenState {
        let rows = tracks.map { track in
            let isCurrent = currentContext == .trackList && currentTrackId == track.id

            return rowStateBuilder.build(
                track: track,
                snapshot: snapshotsByTrackId[track.trackId],
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                isHighlighted: highlightedRowId == track.id,
                settings: settings,
                collectionNavigationTarget: collectionNavigationTargetsByTrackId[track.trackId]
            )
        }

        let scrollTargetRowId = rows.first(where: { $0.isCurrent })?.id

        return TrackListScreenState(
            id: id,
            title: title,
            summary: summary,
            rows: rows,
            scrollTargetRowId: scrollTargetRowId
        )
    }
}
