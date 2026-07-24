//
//  TrackSection.swift
//  TrackList
//
//  Модель секции по дате
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation

/// Описывает смысл заголовка секции без формирования готовой пользовательской строки.
enum TrackSectionHeader: Hashable {
    /// Секция не имеет заголовка.
    case hidden
    /// Секция сгруппирована по дате добавления треков.
    case date(Date)
    /// Заголовок является пользовательскими метаданными трека.
    case metadata(String)
    /// В metadata исполнителя нет значения.
    case unknownArtist
}

struct TrackSection: Identifiable, Equatable {
    let id: String
    /// Семантический заголовок для преобразования в presentation-слое.
    let header: TrackSectionHeader
    let tracks: [LibraryTrack]

    /// Заголовок нужен для всех секций, кроме плоской сортировки.
    var showsHeader: Bool {
        header != .hidden
    }

    init(
        id: String,
        header: TrackSectionHeader,
        tracks: [LibraryTrack]
    ) {
        self.id = id
        self.header = header
        self.tracks = tracks
    }

    // SwiftUI должен видеть изменение порядка строк даже при прежнем количестве треков.
    static func == (lhs: TrackSection, rhs: TrackSection) -> Bool {
        lhs.id == rhs.id
            && lhs.header == rhs.header
            && lhs.tracks.map(\.id) == rhs.tracks.map(\.id)
    }
}
