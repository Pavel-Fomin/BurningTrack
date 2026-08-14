//
//  TrackListScreenStateBuilder.swift
//  TrackList
//
//  Преобразует данные detail-flow треклиста в готовый ScreenState без SwiftUI-зависимостей.
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
    ///   - title: Сохранённое название треклиста.
    ///   - kind: Назначение треклиста для выбора системного заголовка.
    ///   - canRenameTrackList: Доступно ли переименование треклиста.
    ///   - summary: Семантическая статистика для преобразования во View.
    ///   - tracks: Треки треклиста.
    ///   - snapshotsByTrackId: Runtime snapshots треков по физическому id трека.
    ///   - currentTrackId: Идентификатор текущего TrackDisplayable; для Track это id строки треклиста.
    ///   - currentContext: Контекст текущего воспроизведения.
    ///   - isPlaying: Идёт ли воспроизведение.
    ///   - highlightedRowId: Идентификатор подсвеченной строки.
    ///   - favoriteTrackIds: Подтверждённые идентификаторы треков из единого состояния «Избранного».
    ///   - settings: Снимок настроек отображения строк.
    /// - Returns: Готовое состояние экрана.
    func build(
        id: UUID,
        title: String,
        kind: TrackListKind,
        canRenameTrackList: Bool,
        summary: TrackCollectionSummary?,
        tracks: [Track],
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        currentTrackId: UUID?,
        currentContext: PlaybackContext?,
        isPlaying: Bool,
        highlightedRowId: UUID?,
        favoriteTrackIds: Set<UUID>,
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
                isFavorite: favoriteTrackIds.contains(track.trackId),
                settings: settings,
                collectionNavigationTarget: collectionNavigationTargetsByTrackId[track.trackId]
            )
        }

        let scrollTargetRowId = rows.first(where: { $0.isCurrent })?.id

        return TrackListScreenState(
            id: id,
            title: TrackListPresentationText.title(
                for: kind,
                storedName: title
            ),
            canRenameTrackList: canRenameTrackList,
            summary: summary,
            rows: rows,
            scrollTargetRowId: scrollTargetRowId
        )
    }
}
