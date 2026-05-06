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
//  - используется только как слой преобразования между ошибкой и пользовательским сообщением.
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
            return .operationFailed(message: "Файл не найден")

        case .fileAccessDenied:
            return .operationFailed(message: "Нет доступа к файлу")

        case .fileNotPlayable:
            return .operationFailed(message: "Файл нельзя воспроизвести")

        case .fileAlreadyExists:
            return .operationFailed(message: "Файл уже существует")

        case .fileMoveFailed:
            return .fileMoveFailed

        case .fileRenameFailed:
            return .fileRenameFailed

        // MARK: - Закладки доступа

        case .bookmarkMissing:
            return .operationFailed(message: "Доступ к файлу не найден")

        case .bookmarkStale:
            return .operationFailed(message: "Доступ к файлу устарел")

        case .bookmarkResolveFailed:
            return .operationFailed(message: "Не удалось восстановить доступ к файлу")

        case .bookmarkCreateFailed:
            return .operationFailed(message: "Не удалось сохранить доступ к файлу")

        // MARK: - Фонотека

        case .libraryFolderAccessDenied:
            return .operationFailed(message: "Нет доступа к папке")

        case .libraryFolderUnavailable:
            return .operationFailed(message: "Папка фонотеки недоступна")

        case .libraryRestoreFailed:
            return .operationFailed(message: "Не удалось восстановить доступ к фонотеке")

        case .librarySyncFailed:
            return .operationFailed(message: "Не удалось обновить фонотеку")

        // MARK: - Треки

        case .trackUnavailable:
            return .trackUnavailable(title: "Трек")

        case .trackNotFound:
            return .operationFailed(message: "Трек не найден")

        // MARK: - Треклисты

        case .trackListNotFound:
            return .operationFailed(message: "Треклист не найден")

        case .trackListLoadFailed:
            return .operationFailed(message: "Не удалось загрузить треклист")

        case .trackListSaveFailed:
            return .trackListSaveFailed

        case .trackListNameInvalid:
            return .operationFailed(message: "Некорректное имя треклиста")

        // MARK: - Плеер

        case .playlistLoadFailed:
            return .operationFailed(message: "Не удалось загрузить плеер")

        case .playlistSaveFailed:
            return .playlistSaveFailed

        // MARK: - Импорт

        case .importFailed:
            return .importFailed

        case .importPartiallyFailed:
            return .operationFailed(message: "Импорт выполнен частично")

        // MARK: - Экспорт

        case .exportNoTracks:
            return .noTracksToExport

        case .exportNoFilesPrepared:
            return .operationFailed(message: "Нет файлов для экспорта")

        case .exportFailed:
            return .exportFailed

        // MARK: - Воспроизведение

        case .playbackFailed:
            return .playbackFailed(title: "Трек")

        case .audioSessionFailed:
            return .operationFailed(message: "Не удалось подготовить звук")

        // MARK: - Метаданные

        case .metadataReadFailed:
            return .operationFailed(message: "Не удалось прочитать данные трека")

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
            return .operationFailed(message: "Неизвестная ошибка")
        }
    }
}
