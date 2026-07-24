//
//  ExportPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя экспорта.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует semantic состояние экспорта в подписи обычного пользовательского интерфейса.
enum ExportPresentationText {
    static var exportingTitle: String {
        String(localized: "Exporting")
    }

    static var closeResultAccessibilityLabel: String {
        String(localized: "Close Export Result")
    }

    static var progressAccessibilityLabel: String {
        String(localized: "Export Progress")
    }

    static var noExportDataTitle: String {
        String(localized: "No Export Data")
    }

    static var noExportDataDescription: String {
        String(localized: "This operation has already completed or was closed.")
    }

    static var detailsNavigationTitle: String {
        String(localized: "Export Tracks")
    }

    static var folderTitle: String {
        String(localized: "Folder")
    }

    static var destinationTitle: String {
        String(localized: "Destination")
    }

    static var filesTitle: String {
        String(localized: "Files")
    }

    static var currentFileTitle: String {
        String(localized: "Current")
    }

    static var cancelExportTitle: String {
        String(localized: "Cancel Export")
    }

    static func statusTitle(for state: ExportState) -> String {
        switch state {
        case .idle:
            return String(localized: "Waiting")
        case .preparing:
            return String(localized: "Preparing Files")
        case .copying:
            return String(localized: "Copying Files")
        case .completed:
            return String(localized: "Export Complete")
        case .completedWithErrors:
            return String(localized: "Export Completed with Errors")
        case .cancelled:
            return String(localized: "Export Cancelled")
        case .failed:
            return String(localized: "Export Failed")
        }
    }

    static func fileProgress(
        completedCount: Int,
        totalCount: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "export.filesProgress"),
            completedCount,
            totalCount
        )
    }

    static func byteProgress(
        copiedBytes: String,
        totalBytes: String
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "export.bytesProgress"),
            copiedBytes,
            totalBytes
        )
    }

    static func failureCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "export.failureCount"),
            count
        )
    }

    static func progressAccessibilityValue(percentage: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "export.progressAccessibility"),
            percentage
        )
    }

    static func preparedMessage(targetName: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.export.prepared"),
            targetName
        )
    }

    static var noTracksMessage: String {
        String(localized: "toast.export.noTracks")
    }

    static var noFilesPreparedMessage: String {
        String(localized: "toast.export.noFilesPrepared")
    }

    static var failedMessage: String {
        String(localized: "toast.export.failed")
    }

    static var alreadyRunningMessage: String {
        String(localized: "toast.export.alreadyRunning")
    }

    static var destinationSelectionFailedMessage: String {
        String(localized: "toast.export.destinationSelectionFailed")
    }

    static func partialExportDetails(
        exported: Int,
        failed: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.export.partialDetails"),
            exported,
            failed
        )
    }

    static var partialExportMessage: String {
        statusTitle(for: .completedWithErrors)
    }

    /// Преобразует семантический источник экспорта в подпись интерфейса.
    static func displaySourceName(
        for source: ExportFolder?,
        fallback: String = ""
    ) -> String {
        switch source {
        case .playerQueue:
            return String(localized: "Player")
        case .libraryTracks:
            return String(localized: "Tracks")
        case .purchasedITunes:
            return String(localized: "Purchased in iTunes")
        case .named(let name):
            return name
        case nil:
            return fallback
        }
    }
}
