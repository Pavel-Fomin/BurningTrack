//
//  AppError.swift
//  TrackList
//
//  Список всех возможных ошибок приложения
//
//  Created by Pavel Fomin on 20.05.2025.
//

import Foundation

enum AppError: Error, Sendable, Equatable {
    case fileNotFound
    case fileAccessDenied
    case fileNotPlayable
    case fileAlreadyExists
    case fileMoveFailed
    case fileRenameFailed
    case purchasedITunesCopyFailed
    case bookmarkMissing
    case bookmarkStale
    case bookmarkResolveFailed
    case bookmarkCreateFailed
    case libraryFolderAccessDenied
    case libraryFolderUnavailable
    case libraryRestoreFailed
    case librarySyncFailed
    case trackUnavailable
    case trackNotFound
    case trackListNotFound
    case trackListLoadFailed
    case trackListSaveFailed
    case trackListNameInvalid
    /// Системный треклист нельзя переименовывать.
    case trackListRenameNotAllowed
    /// Системный треклист нельзя удалять.
    case trackListDeletionNotAllowed
    /// Системный треклист нельзя перемещать в пользовательском порядке.
    case trackListReorderNotAllowed
    case playlistLoadFailed
    case playlistSaveFailed
    case importFailed
    case importPartiallyFailed
    case exportNoTracks
    case exportNoFilesPrepared
    case exportFailed
    case playbackFailed
    case audioSessionFailed
    case metadataReadFailed
    /// Файл изменён, но новое сохранённое состояние трека не удалось подтвердить.
    case trackUpdateConfirmationFailed
    case tagWriteFailed
    case artworkLoadFailed
    case showInLibraryFailed
    case presenterUnavailable
    case unknown
}

/// Этап mutation-пайплайна, на котором операция не получила подтверждённый итог.
enum MutationStage: Sendable, Equatable {
    case validate
    case prepare
    case perform
    case persist
    case confirm
}

/// Состояние внешних изменений к моменту ошибки mutation-пайплайна.
enum MutationRecoveryState: Sendable, Equatable {
    /// Операция не изменила внешнее состояние.
    case untouched
    /// Файл уже изменён, но зависимые записи ещё не подтверждены.
    case physicalChangeCompleted
    /// Все записи завершены, но финальное подтверждение отсутствует.
    case confirmationMissing
    /// Security-scoped доступ уже закрыт, хотя удаление связанных записей не подтверждено.
    case accessReleased
    /// Все изменения, выполненные до ошибки, возвращены к подтверждённому исходному состоянию.
    case restored
    /// Обратное действие не завершилось, поэтому состояние требует явного восстановления.
    case rollbackFailed
}

/// Семантическая ошибка изменяющей операции без передачи небезопасного произвольного Error через async-границу.
struct MutationFailure: Error, Sendable {
    let stage: MutationStage
    let appError: AppError
    let recovery: MutationRecoveryState
    /// Диагностика исходной ошибки сохраняется как значение, безопасное для async-границ.
    let operationErrorDescription: String?
    /// Диагностика ошибки обратного действия не должна маскироваться исходной ошибкой.
    let recoveryErrorDescription: String?

    init(
        stage: MutationStage,
        appError: AppError,
        recovery: MutationRecoveryState,
        operationErrorDescription: String? = nil,
        recoveryErrorDescription: String? = nil
    ) {
        self.stage = stage
        self.appError = appError
        self.recovery = recovery
        self.operationErrorDescription = operationErrorDescription
        self.recoveryErrorDescription = recoveryErrorDescription
    }
}
