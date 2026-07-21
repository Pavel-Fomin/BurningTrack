//
//  BatchTagEditPresentationText.swift
//  TrackList
//
//  Локализованные подписи общей оболочки массового редактирования тегов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует semantic состояния общей оболочки Batch Tag Edit в подписи интерфейса.
enum BatchTagEditPresentationText {
    static var navigationTitle: String {
        String(localized: "Edit Tags")
    }

    static var loadingSelectedTracksTitle: String {
        String(localized: "Reading Selected Track Tags…")
    }

    static var savingSelectedTracksTitle: String {
        String(localized: "Updating Selected Track Tags…")
    }

    static var compressArtworkTitle: String {
        String(localized: "Compress")
    }

    static var artworkActionsAccessibilityLabel: String {
        String(localized: "Artwork Actions")
    }

    static var allSelectedTracksAccessibilityLabel: String {
        String(localized: "All Selected Tracks")
    }

    static var noArtworkTitle: String {
        String(localized: "No Artwork")
    }

    static func selectedTracksAccessibilityValue(for count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "batchTag.selectedTracks"),
            count
        )
    }

    static func artworkPreviewAccessibilityLabel(
        title: String,
        hasArtwork: Bool
    ) -> String {
        if hasArtwork {
            return String.localizedStringWithFormat(
                String(localized: "Artwork for %@"),
                title
            )
        }

        return String.localizedStringWithFormat(
            String(localized: "No Artwork for %@"),
            title
        )
    }

    static func compressionOptionTitle(
        for option: BatchArtworkCompressionOption
    ) -> String {
        "\(option.maxPixelSize) × \(option.maxPixelSize)"
    }

    static func compressionFailureText(for count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "batchTag.artworkCompressionFailure"),
            count
        )
    }

    static var tagsUpdatedMessage: String {
        String(localized: "toast.tagEditor.tagsUpdated")
    }

    static var tagsPartiallyUpdatedMessage: String {
        String(localized: "toast.batchTag.tagsPartiallyUpdated")
    }

    static var tagsUpdateFailedMessage: String {
        String(localized: "toast.batchTag.tagsUpdateFailed")
    }

    static func updatedTracksDetails(count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.batchTag.updatedTracksDetails"),
            count
        )
    }

    static func partialUpdateDetails(
        succeeded: Int,
        failed: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.batchTag.partialUpdateDetails"),
            succeeded,
            failed
        )
    }

    static func failedUpdateDetails(failed: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.batchTag.failedUpdateDetails"),
            failed
        )
    }
}
