//
//  ToastPresentation.swift
//  TrackList
//
//  Преобразование семантических toast-событий в данные представления.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import SwiftUI

/// Собирает готовые данные toast из семантических событий без управления их жизненным циклом.
enum ToastPresentation {
    static func makeData(from event: ToastEvent) -> ToastData {
        switch event {
        case let .trackMovedToPlayer(title, artist, artwork),
             let .trackAddedToPlayer(title, artist, artwork):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: PlayerPresentationText.trackAddedToPlayerMessage
            )

        case let .trackRemovedFromPlayer(title, artist, artwork):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: PlayerPresentationText.trackRemovedFromPlayerMessage
            )

        case .playerCleared:
            return listToast(message: PlayerPresentationText.playerClearedMessage)

        case let .trackListSaved(name):
            return listToast(
                name: name,
                message: TrackListPresentationText.savedMessage(name: name)
            )

        case let .trackListCreated(name):
            return listToast(
                name: name,
                message: TrackListPresentationText.createdMessage
            )

        case let .trackListCleared(name):
            return listToast(
                name: name,
                message: TrackListPresentationText.clearedMessage
            )

        case let .tracksAddedToTrackList(count, name):
            return listToast(
                name: name,
                message: TrackListPresentationText.tracksAddedMessage(count: count)
            )

        case .playlistSaved:
            return listToast(message: PlayerPresentationText.playlistSavedMessage)

        case let .exportPrepared(targetName):
            return listToast(
                name: targetName,
                message: ExportPresentationText.preparedMessage(targetName: targetName)
            )

        case let .tracksAddedToPlayer(count):
            return listToast(
                message: PlayerPresentationText.tracksAddedToPlayerMessage(count: count)
            )

        case let .trackAddedToTrackList(title, artist, artwork, trackListName):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: TrackListPresentationText.trackAddedMessage(name: trackListName)
            )

        case let .trackMovedInLibrary(title, artist, artwork, folderName):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: MoveToFolderPresentationText.trackMovedMessage(
                    folderName: folderName
                )
            )

        case let .trackCopiedFromITunes(title, artist, artwork, folderName):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: MoveToFolderPresentationText.purchasedITunesTrackCopiedMessage(
                    folderName: folderName
                )
            )

        case let .folderAdded(name):
            return listToast(
                name: name,
                message: LibraryPresentationText.folderAddedMessage
            )

        case let .folderRemoved(name):
            return listToast(
                name: name,
                message: LibraryPresentationText.folderRemovedMessage
            )

        case let .trackRemovedFromTrackList(title, artist, artwork):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: TrackListPresentationText.trackRemovedMessage
            )

        case let .trackListRenamed(newName):
            return listToast(
                name: newName,
                message: TrackListPresentationText.renamedMessage
            )

        case let .tagsUpdated(title, artist, artwork):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: TagEditorPresentationText.tagsUpdatedMessage
            )

        case let .batchTagsUpdated(count):
            return listToast(
                name: BatchTagEditPresentationText.updatedTracksDetails(count: count),
                message: BatchTagEditPresentationText.tagsUpdatedMessage
            )

        case let .batchTagsPartiallyUpdated(succeeded, failed):
            return listToast(
                name: BatchTagEditPresentationText.partialUpdateDetails(
                    succeeded: succeeded,
                    failed: failed
                ),
                message: BatchTagEditPresentationText.tagsPartiallyUpdatedMessage
            )

        case let .batchTagsUpdateFailed(failed):
            return listToast(
                name: BatchTagEditPresentationText.failedUpdateDetails(failed: failed),
                message: BatchTagEditPresentationText.tagsUpdateFailedMessage
            )

        case let .fileRenamed(newName):
            return listToast(
                name: newName,
                message: FileRenamePresentationText.renamedMessage
            )

        case let .fileAndTagsUpdated(title, artist, artwork):
            return trackToast(
                title: title,
                artist: artist,
                artwork: artwork,
                message: TagEditorPresentationText.fileAndTagsUpdatedMessage
            )

        case let .trackUnavailable(title):
            return trackToast(
                title: displayTrackTitle(title),
                artist: "",
                artwork: nil,
                message: AppMessagePresentationText.trackUnavailableMessage
            )

        case .noTracksToExport:
            return listToast(message: ExportPresentationText.noTracksMessage)

        case let .partialImport(imported, failed):
            return listToast(
                name: LibraryPresentationText.partialImportDetails(
                    imported: imported,
                    failed: failed
                ),
                message: LibraryPresentationText.importPartiallyFailedMessage
            )

        case let .partialExport(exported, failed):
            return listToast(
                name: ExportPresentationText.partialExportDetails(
                    exported: exported,
                    failed: failed
                ),
                message: ExportPresentationText.partialExportMessage
            )

        case let .libraryAccessNeedsRestore(folderName):
            return listToast(
                name: folderName ?? "",
                message: LibraryPresentationText.libraryAccessNeedsRestoreMessage
            )

        case .showInLibraryTargetMissing:
            return listToast(
                message: LibraryPresentationText.showInLibraryTargetMissingMessage
            )

        case .folderNotFound:
            return listToast(message: LibraryPresentationText.folderNotFoundMessage)

        case .artworkCouldNotBeLoaded:
            return listToast(message: TagEditorPresentationText.artworkLoadFailedMessage)

        case let .operationFailed(message):
            return listToast(message: message)

        case let .playbackFailed(title):
            return trackToast(
                title: displayTrackTitle(title),
                artist: "",
                artwork: nil,
                message: PlayerPresentationText.playbackFailedMessage
            )

        case .audioSessionFailed:
            return listToast(message: PlayerPresentationText.audioSessionFailedMessage)

        case .trackListSaveFailed:
            return listToast(message: TrackListPresentationText.saveFailedMessage)

        case .playlistSaveFailed:
            return listToast(message: PlayerPresentationText.playlistSaveFailedMessage)

        case .importFailed:
            return listToast(message: LibraryPresentationText.importFailedMessage)

        case .exportFailed:
            return listToast(message: ExportPresentationText.failedMessage)

        case .fileMoveFailed:
            return listToast(message: MoveToFolderPresentationText.fileMoveFailedMessage)

        case .fileRenameFailed:
            return listToast(message: FileRenamePresentationText.fileRenameFailedMessage)

        case .tagWriteFailed:
            return listToast(message: TrackDetailPresentationText.tagWriteFailedMessage)

        case let .libraryAccessDenied(folderName):
            return listToast(
                name: folderName ?? "",
                message: LibraryPresentationText.libraryAccessDeniedMessage
            )

        case .presenterUnavailable:
            return listToast(message: AppMessagePresentationText.presenterUnavailableMessage)
        }
    }

    /// Собирает toast, связанный с конкретным треком.
    private static func trackToast(
        title: String,
        artist: String,
        artwork: Image?,
        message: String
    ) -> ToastData {
        ToastData(
            style: .track(title: title, artist: artist),
            artworkImage: artwork,
            message: message
        )
    }

    /// Подставляет локализованное имя, если событие не содержит названия трека.
    private static func displayTrackTitle(_ title: String?) -> String {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              title.isEmpty == false else {
            return AppMessagePresentationText.genericTrackTitle
        }

        return title
    }

    /// Собирает toast без изображения трека.
    private static func listToast(
        name: String = "",
        message: String
    ) -> ToastData {
        ToastData(
            style: .trackList(name: name),
            artworkImage: nil,
            message: message
        )
    }
}
