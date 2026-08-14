//
//  BatchTagEditTrack.swift
//  TrackList
//
//  Снимок данных одного трека для формы массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

struct BatchTagEditTrack: Identifiable, Equatable {
    let trackId: UUID
    let fileName: String
    let values: [EditableTrackField: String]
    let hasArtwork: Bool
    var id: UUID { trackId
    }
}
