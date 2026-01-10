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

    // MARK: - Internal logic

    private func show(_ newToast: ToastData, duration: TimeInterval) {

        dismissTask?.cancel()

        // Защита от дублей
        if data == newToast {
            return
        }

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

        case let .tagsUpdated(title, artist):
            return ToastData(
                style: .track(title: title, artist: artist),
                artworkImage: nil,
                message: "Теги обновлены"
            )

        case let .fileRenamed(newName):
            return ToastData(
                style: .trackList(name: newName),
                artworkImage: nil,
                message: "Файл переименован"
            )
        }
    }
}
