//
//  TrackDetailPresentationText.swift
//  TrackList
//
//  Локализованные подписи режимов просмотра и редактирования Track Detail.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует состояния Track Detail в подписи интерфейса без изменения метаданных.
enum TrackDetailPresentationText {
    static var navigationTitle: String {
        String(localized: "Track Info")
    }

    static var filePathTitle: String {
        String(localized: "File Path")
    }

    static var aboutFileTitle: String {
        String(localized: "About File")
    }

    static var unavailableTechnicalValue: String {
        String(localized: "Unavailable")
    }

    static var missingMetadataValue: String {
        String(localized: "Not Set")
    }

    static var closeAccessibilityLabel: String {
        String(localized: "Close")
    }

    static var cancelAccessibilityLabel: String {
        String(localized: "Cancel")
    }

    static var editAccessibilityLabel: String {
        String(localized: "Edit")
    }

    static var saveAccessibilityLabel: String {
        String(localized: "Save")
    }

    static var trackIsPlayingTitle: String {
        String(localized: "Track Is Playing")
    }

    static var stopAndSaveTitle: String {
        String(localized: "Stop and Save")
    }

    static var stopPlaybackDescription: String {
        String(localized: "To rename the file, stop playback first.")
    }

    static var fileNameConflictTitle: String {
        String(localized: "A File with This Name Already Exists")
    }

    static var fileNameConflictDescription: String {
        String(localized: "Choose a Different File Name.")
    }

    static var acknowledgeTitle: String {
        String(localized: "OK")
    }

    static var saveFailedMessage: String {
        String(localized: "toast.trackDetail.saveFailed")
    }

    static var metadataReadFailedMessage: String {
        String(localized: "toast.trackDetail.metadataReadFailed")
    }

    static var tagWriteFailedMessage: String {
        saveFailedMessage
    }
}
