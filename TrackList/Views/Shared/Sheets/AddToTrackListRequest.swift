//
//  AddToTrackListRequest.swift
//  TrackList
//
//  Нормализованный запрос feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Неизменяемый контекст добавления, скрывающий неоднородный AppSheet payload от feature-слоя.
struct AddToTrackListRequest {
    /// Идентификаторы треков в исходном пользовательском порядке.
    let trackIds: [UUID]
    /// Семантический источник треков для выбора существующей доменной команды.
    let source: AddToTrackListSource
    /// Треклист-источник, недоступный как destination в текущем flow.
    let excludedTrackListId: UUID?
}

/// Описывает источник треков без зависимости ViewModel и ActionHandler от AppSheet payload.
enum AddToTrackListSource {
    /// Один файловый трек из Library, Search или Player.
    case libraryTrack(trackId: UUID)
    /// Купленные iTunes-треки, которым для доменной команды нужны runtime-модели.
    case purchasedITunes(tracks: [PurchasedITunesPlayableTrack])
    /// Массово выбранные треки Library в порядке пользовательского выбора.
    case libraryBatch(tracks: [LibraryTrack])
    /// Треки, добавляемые из другого треклиста через существующую ID-based команду.
    case trackList(trackIds: [UUID])
}

/// Локализует преобразование публичного sheet payload в внутренний запрос feature-flow.
struct AddToTrackListRequestMapper {
    /// Сохраняет текущий порядок треков и приоритет ветвления существующего flow.
    func map(_ data: AddToTrackListSheetData) -> AddToTrackListRequest {
        if let libraryBatchTracks = data.libraryBatchTracks {
            return AddToTrackListRequest(
                trackIds: libraryBatchTracks.map(\.trackId),
                source: .libraryBatch(tracks: libraryBatchTracks),
                excludedTrackListId: data.sourceTrackListId
            )
        }

        let purchasedITunesTracks = data.tracks.compactMap {
            $0.asPurchasedITunesPlayableTrack()
        }
        if !purchasedITunesTracks.isEmpty,
           purchasedITunesTracks.count == data.tracks.count {
            return AddToTrackListRequest(
                trackIds: purchasedITunesTracks.map(\.trackId),
                source: .purchasedITunes(tracks: purchasedITunesTracks),
                excludedTrackListId: data.sourceTrackListId
            )
        }

        if let sourceTrackListId = data.sourceTrackListId {
            return AddToTrackListRequest(
                trackIds: data.trackIds,
                source: .trackList(trackIds: data.trackIds),
                excludedTrackListId: sourceTrackListId
            )
        }

        if let trackId = data.trackIds.first, data.trackIds.count == 1 {
            return AddToTrackListRequest(
                trackIds: [trackId],
                source: .libraryTrack(trackId: trackId),
                excludedTrackListId: nil
            )
        }

        return AddToTrackListRequest(
            trackIds: data.trackIds,
            source: .trackList(trackIds: data.trackIds),
            excludedTrackListId: nil
        )
    }
}
