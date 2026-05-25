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
    let trackId: UUID                        /// Идентификатор трека.
    let fileName: String                     /// Имя файла трека.
    let values: [EditableTrackField: String] /// Значения тегов, прочитанные для этого трека.
    let hasArtwork: Bool                     /// Есть ли у трека обложка.
    var id: UUID { trackId                   /// Идентификатор для SwiftUI-списков.
    }
}
