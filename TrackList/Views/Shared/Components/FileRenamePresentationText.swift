//
//  FileRenamePresentationText.swift
//  TrackList
//
//  Локализованные подписи сценариев переименования файлов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует semantic стратегии и статусы переименования в подписи интерфейса.
enum FileRenamePresentationText {
    static var renameFileTitle: String {
        String(localized: "Rename File")
    }

    static var stopPlaybackTitle: String {
        String(localized: "Track Is Playing")
    }

    static var stopAndRenameTitle: String {
        String(localized: "Stop and Rename")
    }

    static var stopPlaybackDescription: String {
        String(localized: "To rename the file, stop playback first.")
    }

    static var nameConflictTitle: String {
        String(localized: "A File with This Name Already Exists")
    }

    static var nameConflictDescription: String {
        String(localized: "Choose a Different File Name.")
    }

    static var batchRenameTitle: String {
        String(localized: "Rename Files")
    }

    static var batchRenameSubtitle: String {
        String(localized: "Based on Tags")
    }

    static var readingTagsTitle: String {
        String(localized: "Reading Tags…")
    }

    static var renamingFilesTitle: String {
        String(localized: "Renaming Files…")
    }

    static var noFilesTitle: String {
        String(localized: "No Files")
    }

    static var noFilesDescription: String {
        String(localized: "All tracks were excluded from the operation.")
    }

    static var howToRenameTitle: String {
        String(localized: "How to Rename")
    }

    static var chooseStrategyTitle: String {
        String(localized: "Choose")
    }

    static var tagsAreMissingTitle: String {
        String(localized: "Tags Are Missing")
    }

    static var editManuallyTitle: String {
        String(localized: "Edit Manually")
    }

    static func strategyTitle(for strategy: FileRenameStrategy) -> String {
        switch strategy {
        case .artistTitle:
            return String(localized: "Artist – Title")
        case .titleArtist:
            return String(localized: "Title – Artist")
        case .manual:
            return String(localized: "Manual")
        }
    }

    static func strategyTitle(for strategy: FilenameRenameStrategy) -> String {
        switch strategy {
        case .artistTitle:
            return String(localized: "Artist – Title")
        case .titleArtist:
            return String(localized: "Title – Artist")
        }
    }

    static func statusDescription(for status: BatchFilenameRenameStatus) -> String? {
        switch status {
        case .ready:
            return nil
        case .renamed:
            return String(localized: "Renamed")
        case .missingArtist:
            return String(localized: "Artist Is Missing")
        case .missingTitle:
            return String(localized: "Title Is Missing")
        case .missingArtistAndTitle:
            return String(localized: "Artist and Title Are Missing")
        case .invalidTargetName:
            return String(localized: "Invalid File Name")
        case .applyFailed:
            return String(localized: "Couldn't Rename File")
        case .trackIsPlaying:
            return String(localized: "File Is Currently Used by Player")
        case .fileAccessDenied:
            return String(localized: "File Access Unavailable")
        }
    }

    static var renamedMessage: String {
        String(localized: "Renamed")
    }

    static var fileRenameFailedMessage: String {
        String(localized: "Couldn't Rename File")
    }

    static var preparationFailedMessage: String {
        String(localized: "toast.fileRename.preparationFailed")
    }

    static func skippedMessage(for reason: FileRenameSkipReason) -> String {
        switch reason {
        case .tagsMissing:
            return String(localized: "Tags Are Missing")
        case .emptyFileName:
            return String(localized: "toast.fileRename.emptyFileName")
        case .invalidFileName:
            return String(localized: "toast.fileRename.invalidFileName")
        case .unchangedFileName:
            return String(localized: "toast.fileRename.unchangedFileName")
        }
    }

}
