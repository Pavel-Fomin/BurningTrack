//
//  ToastManager.swift
//  TrackList
//
//  Централизованный менеджер отображения Toast'ов.
//  Принимает декларативные ToastEvent и преобразует их в ToastData.
//
//  Единственная точка:
//  - формирования текста
//  - определения стиля
//  - защиты от дублей
//
//  Created by Pavel Fomin on 08.07.2025
//

import SwiftUI

@MainActor
final class ToastManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ToastManager()

    // MARK: - Public state

    @Published private(set) var data: ToastData?   /// Текущий тост (nil — ничего не отображается)

    // MARK: - Private

    private var dismissTask: Task<Void, Never>?

    // MARK: - Public API

    /// Основной вход для показа тостов из ViewModel
    func handle(_ event: ToastEvent, duration: TimeInterval = 2.0) {

        let toastData = makeToastData(from: event)

        show(toastData, duration: duration)
    }

    /// Показывает Toast на основе ошибки приложения.
    /// Использует централизованный маппинг AppError -> ToastEvent.
    func handle(_ error: AppError) {
        handle(error.toastEvent)
    }

    // MARK: - Internal logic

    private func show(_ newToast: ToastData, duration: TimeInterval) {

        // Защита от дублей
        if data == newToast {
            return
        }

        dismissTask?.cancel()

        data = newToast

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if self.data == newToast {
                self.data = nil
            }
        }
    }

    // MARK: - Mapping

    private func makeToastData(from event: ToastEvent) -> ToastData {

        switch event {

        // MARK: - Плеер

        case let .trackMovedToPlayer(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Добавлен в плеер"
            )

        case let .trackRemovedFromPlayer(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Удалён из плеера"
            )
            
        case .playerCleared:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Плеер очищен"
            )

        case let .trackListSaved(name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Треклист «\(name)» сохранён"
            )

        case let .trackListCreated(name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Треклист создан"
            )

        case let .trackListCleared(name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Треклист очищен"
            )

        case let .tracksAddedToTrackList(count, name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Добавлено \(count) треков"
            )

        case .playlistSaved:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Плеер сохранён"
            )

        case let .exportFinished(targetName):
            return ToastData(
                style: .trackList(name: targetName),
                artworkImage: nil,
                message: "Экспорт завершён"
            )

        // MARK: - Фонотека

        case let .trackAddedToPlayer(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Добавлен в плеер"
            )

        case let .trackAddedToTrackList(title, artist, artwork, trackListName):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Добавлен в «\(trackListName)»"
            )

        case let .trackMovedInLibrary(title, artist, artwork, folderName):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Перемещён в «\(folderName)»"
            )

        case let .folderAdded(name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Папка добавлена"
            )

        case let .folderRemoved(name):
            return ToastData(
                style: .trackList(name: name),
                artworkImage: nil,
                message: "Папка откреплена"
            )

        // MARK: - Треклист

        case let .trackRemovedFromTrackList(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Удалён из треклиста"
            )

        case let .trackListRenamed(newName):
            return ToastData(
                style: .trackList(name: newName),
                artworkImage: nil,
                message: "Треклист переименован"
            )

        // MARK: - Глобальные

        case let .tagsUpdated(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Теги обновлены"
            )

        case let .fileRenamed(newName):
            return ToastData(
                style: .trackList(name: newName),
                artworkImage: nil,
                message: "Файл переименован"
            )
            
        case let .fileAndTagsUpdated(title, artist, artwork):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: artwork,
                message: "Обновлены: имя файла, теги"
            )

        // MARK: - Warning

        case let .trackUnavailable(title):
            return ToastData(
                style: .track(title: title, artist: ""),
                artworkImage: nil,
                message: "Трек недоступен"
            )

        case .noTracksToExport:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Нет треков для экспорта"
            )

        case let .partialImport(imported, failed):
            return ToastData(
                style: .trackList(name: "Импортировано: \(imported), ошибок: \(failed)"),
                artworkImage: nil,
                message: "Импорт выполнен частично"
            )

        case let .partialExport(exported, failed):
            return ToastData(
                style: .trackList(name: "Экспортировано: \(exported), ошибок: \(failed)"),
                artworkImage: nil,
                message: "Экспорт выполнен частично"
            )

        case let .libraryAccessNeedsRestore(folderName):
            return ToastData(
                style: .trackList(name: folderName),
                artworkImage: nil,
                message: "Нужен доступ к папке"
            )

        case .showInLibraryTargetMissing:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Трек не найден в фонотеке"
            )

        case .artworkCouldNotBeLoaded:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Обложку не удалось загрузить"
            )

        // MARK: - Error

        case let .operationFailed(message):
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: message
            )

        case let .playbackFailed(title):
            return ToastData(
                style: .track(title: title, artist: ""),
                artworkImage: nil,
                message: "Не удалось воспроизвести трек"
            )

        case .trackListSaveFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось сохранить треклист"
            )

        case .playlistSaveFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось сохранить плеер"
            )

        case .importFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось импортировать треки"
            )

        case .exportFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось экспортировать треки"
            )

        case .fileMoveFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось переместить файл"
            )

        case .fileRenameFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось переименовать файл"
            )

        case .tagWriteFailed:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось сохранить изменения"
            )

        case let .libraryAccessDenied(folderName):
            return ToastData(
                style: .trackList(name: folderName),
                artworkImage: nil,
                message: "Нет доступа к папке"
            )

        case .presenterUnavailable:
            return ToastData(
                style: .trackList(name: ""),
                artworkImage: nil,
                message: "Не удалось открыть системное окно"
            )
        }
    }
}
