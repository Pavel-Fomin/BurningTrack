//
//  TagEditorPresentationText.swift
//  TrackList
//
//  Локализованные подписи общих полей и artwork редакторов тегов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует semantic поля тегов в подписи Track Detail и Batch Tag Editor.
enum TagEditorPresentationText {
    static var fileNameTitle: String {
        String(localized: "File Name")
    }

    static var mixedPlaceholder: String {
        String(localized: "Mixed")
    }

    static var addArtworkTitle: String {
        String(localized: "Add Artwork")
    }

    static var removeArtworkTitle: String {
        String(localized: "Remove Artwork")
    }

    static func artworkAccessibilityLabel(hasArtwork: Bool) -> String {
        hasArtwork
            ? String(localized: "Artwork")
            : String(localized: "No Artwork")
    }

    static func fieldTitle(for field: EditableTrackField) -> String {
        switch field {
        case .title:
            return String(localized: "Title")
        case .artist:
            return String(localized: "Artist")
        case .album:
            return String(localized: "Album")
        case .genre:
            return String(localized: "Genre")
        case .year:
            return String(localized: "Year")
        case .publisher:
            return String(localized: "Label")
        case .comment:
            return String(localized: "Comment")
        }
    }

    static var tagsUpdatedMessage: String {
        String(localized: "toast.tagEditor.tagsUpdated")
    }

    static var fileAndTagsUpdatedMessage: String {
        String(localized: "toast.tagEditor.fileAndTagsUpdated")
    }

    static var artworkLoadFailedMessage: String {
        String(localized: "toast.tagEditor.artworkLoadFailed")
    }
}
