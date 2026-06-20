//
//  CreateTrackListActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow создания треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class CreateTrackListActionHandler {

    /// Текущее название треклиста в форме.
    private var name: String
    /// Передаёт обновлённое название владельцу состояния.
    private let onNameChanged: (String) -> Void
    /// Управляет созданием треклистов.
    private let trackListsManager: TrackListsManager
    /// Показывает пользовательские сообщения.
    private let toastManager: ToastManager
    /// Управляет открытием и закрытием sheet.
    private let sheetManager: SheetManager

    init(
        name: String,
        onNameChanged: @escaping (String) -> Void,
        trackListsManager: TrackListsManager = .shared,
        toastManager: ToastManager? = nil,
        sheetManager: SheetManager? = nil
    ) {
        self.name = name
        self.onNameChanged = onNameChanged
        self.trackListsManager = trackListsManager
        self.toastManager = toastManager ?? .shared
        self.sheetManager = sheetManager ?? .shared
    }

    /// Выполняет действие sheet-flow создания треклиста.
    func handle(_ action: CreateTrackListAction) {
        switch action {
        case .nameChanged(let newName):
            name = newName
            onNameChanged(newName)

        case .createEmpty:
            createEmptyTrackList()

        case .addTracks:
            openSelectionForCreate()

        case .cancel:
            sheetManager.closeActive()
        }
    }

    /// Создаёт пустой треклист и закрывает sheet.
    private func createEmptyTrackList() {
        let trimmedName = trimmedName()

        guard !trimmedName.isEmpty else { return }

        do {
            let created = try trackListsManager.createEmptyTrackList(withName: trimmedName)
            toastManager.handle(.trackListCreated(name: created.name))
        } catch let appError as AppError {
            PersistentLogger.log("CreateTrackListContainer: create empty tracklist failed error=\(appError)")
            toastManager.handle(appError)
            return
        } catch {
            PersistentLogger.log("CreateTrackListContainer: create empty tracklist failed error=\(error)")
            toastManager.handle(AppError.trackListSaveFailed)
            return
        }

        sheetManager.closeActive()
    }

    /// Открывает выбор треков для создания треклиста после подтверждения.
    private func openSelectionForCreate() {
        let trimmedName = trimmedName()

        guard !trimmedName.isEmpty else { return }

        sheetManager.presentNewTrackListSelectionForCreate(
            name: trimmedName
        )
    }

    /// Возвращает название без внешних пробелов и переводов строк.
    private func trimmedName() -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
