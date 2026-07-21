//
//  AppError+ToastEvent.swift
//  TrackList
//
//  Связывает ошибки приложения с Toast-событиями.
//
//  Роль:
//  - хранит единый маппинг AppError -> ToastEvent;
//  - не показывает Toast самостоятельно;
//  - не содержит бизнес-логики.
//  - использует presentation-слой для формирования пользовательского сообщения.
//
//  Created by Pavel Fomin on 04.05.2026.
//

import Foundation

extension AppError {

    /// Toast-событие, соответствующее ошибке приложения.
    var toastEvent: ToastEvent {
        switch self {

        // MARK: - Файлы

        case .fileNotFound:
            return .operationFailed(
                message: AppMessagePresentationText.fileNotFoundMessage
            )

        case .fileAccessDenied:
            return .operationFailed(
                message: AppMessagePresentationText.fileAccessDeniedMessage
            )

        case .fileNotPlayable:
            return .operationFailed(
                message: PlayerPresentationText.trackNotPlayableMessage
            )

        case .fileAlreadyExists:
            return .operationFailed(
                message: FileRenamePresentationText.nameConflictTitle
            )

        case .fileMoveFailed:
            return .fileMoveFailed

        case .fileRenameFailed:
            return .fileRenameFailed

        case .purchasedITunesCopyFailed:
            return .operationFailed(
                message: MoveToFolderPresentationText.purchasedITunesTrackCopyFailedMessage
            )

        // MARK: - Закладки доступа

        case .bookmarkMissing:
            return .operationFailed(
                message: AppMessagePresentationText.bookmarkMissingMessage
            )

        case .bookmarkStale:
            return .operationFailed(
                message: AppMessagePresentationText.bookmarkStaleMessage
            )

        case .bookmarkResolveFailed:
            return .operationFailed(
                message: AppMessagePresentationText.bookmarkResolveFailedMessage
            )

        case .bookmarkCreateFailed:
            return .operationFailed(
                message: AppMessagePresentationText.bookmarkCreateFailedMessage
            )

        // MARK: - Фонотека

        case .libraryFolderAccessDenied:
            return .operationFailed(
                message: LibraryPresentationText.libraryAccessDeniedMessage
            )

        case .libraryFolderUnavailable:
            return .operationFailed(
                message: LibraryPresentationText.libraryFolderUnavailableMessage
            )

        case .libraryRestoreFailed:
            return .operationFailed(
                message: LibraryPresentationText.libraryRestoreFailedMessage
            )

        case .librarySyncFailed:
            return .operationFailed(
                message: LibraryPresentationText.librarySyncFailedMessage
            )

        // MARK: - Треки

        case .trackUnavailable:
            return .trackUnavailable(title: nil)

        case .trackNotFound:
            return .operationFailed(
                message: AppMessagePresentationText.trackNotFoundMessage
            )

        // MARK: - Треклисты

        case .trackListNotFound:
            return .operationFailed(
                message: TrackListPresentationText.notFoundMessage
            )

        case .trackListLoadFailed:
            return .operationFailed(
                message: TrackListPresentationText.loadFailedMessage
            )

        case .trackListSaveFailed:
            return .trackListSaveFailed

        case .trackListNameInvalid:
            return .operationFailed(
                message: TrackListPresentationText.invalidNameMessage
            )

        // MARK: - Плеер

        case .playlistLoadFailed:
            return .operationFailed(
                message: PlayerPresentationText.playlistLoadFailedMessage
            )

        case .playlistSaveFailed:
            return .playlistSaveFailed

        // MARK: - Импорт

        case .importFailed:
            return .importFailed

        case .importPartiallyFailed:
            return .operationFailed(
                message: LibraryPresentationText.importPartiallyFailedMessage
            )

        // MARK: - Экспорт

        case .exportNoTracks:
            return .noTracksToExport

        case .exportNoFilesPrepared:
            return .operationFailed(
                message: ExportPresentationText.noFilesPreparedMessage
            )

        case .exportFailed:
            return .exportFailed

        // MARK: - Воспроизведение

        case .playbackFailed:
            return .playbackFailed(title: nil)

        case .audioSessionFailed:
            return .audioSessionFailed

        // MARK: - Метаданные

        case .metadataReadFailed:
            return .operationFailed(
                message: TrackDetailPresentationText.metadataReadFailedMessage
            )

        case .tagWriteFailed:
            return .tagWriteFailed

        case .artworkLoadFailed:
            return .artworkCouldNotBeLoaded

        // MARK: - Навигация и системные окна

        case .showInLibraryFailed:
            return .showInLibraryTargetMissing

        case .presenterUnavailable:
            return .presenterUnavailable

        // MARK: - Неизвестная ошибка

        case .unknown:
            return .operationFailed(
                message: AppMessagePresentationText.unknownErrorMessage
            )
        }
    }
}
