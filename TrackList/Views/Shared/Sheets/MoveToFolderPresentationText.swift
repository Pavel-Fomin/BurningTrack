//
//  MoveToFolderPresentationText.swift
//  TrackList
//
//  Локализованные подписи выбора папки назначения.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует semantic режим выбора destination в подписи интерфейса.
enum MoveToFolderPresentationText {
    static func title(for operation: MoveToFolderOperation) -> String {
        switch operation {
        case .move:
            return String(localized: "Move")
        case .copyPurchasedITunes:
            return String(localized: "Copy")
        }
    }

    static func navigationTitle(
        rootTitle: String,
        currentFolderName: String?
    ) -> String {
        currentFolderName ?? rootTitle
    }

    static func selectFolderAccessibilityLabel(for folderName: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Select %@"),
            folderName
        )
    }

    static var currentFolderAccessibilityValue: String {
        String(localized: "Current Folder")
    }

    static func trackMovedMessage(folderName: String?) -> String {
        guard let folderName,
              folderName.isEmpty == false else {
            return String(localized: "toast.move.trackMoved")
        }

        return String.localizedStringWithFormat(
            String(localized: "toast.move.trackMovedToFolder"),
            folderName
        )
    }

    static func purchasedITunesTrackCopiedMessage(folderName: String?) -> String {
        guard let folderName,
              folderName.isEmpty == false else {
            return String(localized: "toast.move.purchasedITunesTrackCopied")
        }

        return String.localizedStringWithFormat(
            String(localized: "toast.move.purchasedITunesTrackCopiedToFolder"),
            folderName
        )
    }

    static var fileMoveFailedMessage: String {
        String(localized: "toast.move.fileMoveFailed")
    }

    static var purchasedITunesTrackPreparationFailedMessage: String {
        String(localized: "toast.move.purchasedITunesTrackPreparationFailed")
    }

    static var purchasedITunesTrackCopyFailedMessage: String {
        String(localized: "toast.move.purchasedITunesTrackCopyFailed")
    }
}
