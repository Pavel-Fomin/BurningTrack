//
//  EditableTrackField.swift
//  TrackList
//
//  Перечень редактируемых полей трека.
//  Используется во всех edit-формах и контейнерах.
//
//  Created by PavelFomin on 19.01.2026.
//

import Foundation

enum EditableTrackField: Hashable, CaseIterable {

    case title
    case artist
    case album
    case genre
    case comment

    /// UI-заголовок поля
    var title: String {
        switch self {
        case .title: return "Название трека"
        case .artist: return "Исполнитель"
        case .album: return "Альбом"
        case .genre: return "Жанр"
        case .comment: return "Комментарий"
        }
    }

    /// Многострочное ли поле
    var isMultiline: Bool {
        self == .comment
    }

    /// Используется ли в форме тегов (без имени файла)
    static var tagFields: [EditableTrackField] {
        [.title, .artist, .album, .genre, .comment]
    }
}
