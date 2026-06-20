//
//  RenameTrackListActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow переименования треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class RenameTrackListActionHandler {

    /// ID треклиста, который нужно переименовать.
    private let trackListId: UUID
    /// Текущее название треклиста в форме.
    private var name: String
    /// Передаёт обновлённое название владельцу состояния.
    private let onNameChanged: (String) -> Void
    /// Выполняет команду переименования треклиста.
    private let commandExecutor: AppCommandExecutor
    /// Показывает пользовательские сообщения.
    private let toastManager: ToastManager
    /// Управляет закрытием sheet.
    private let sheetManager: SheetManager

    init(
        trackListId: UUID,
        name: String,
        onNameChanged: @escaping (String) -> Void,
        commandExecutor: AppCommandExecutor? = nil,
        toastManager: ToastManager? = nil,
        sheetManager: SheetManager? = nil
    ) {
        self.trackListId = trackListId
        self.name = name
        self.onNameChanged = onNameChanged
        self.commandExecutor = commandExecutor ?? .shared
        self.toastManager = toastManager ?? .shared
        self.sheetManager = sheetManager ?? .shared
    }

    /// Выполняет действие sheet-flow переименования треклиста.
    func handle(_ action: RenameTrackListAction) {
        switch action {
        case .nameChanged(let newName):
            name = newName
            onNameChanged(newName)

        case .submit:
            Task {
                await renameTrackList()
            }

        case .cancel:
            sheetManager.closeActive()
        }
    }

    /// Переименовывает треклист через текущий command-flow и закрывает sheet при успехе.
    private func renameTrackList() async {
        let trimmedName = trimmedName()

        guard !trimmedName.isEmpty else { return }

        do {
            try await commandExecutor.renameTrackList(
                trackListId: trackListId,
                newName: trimmedName
            )
            sheetManager.closeActive()
        } catch let appError as AppError {
            print("❌ Ошибка переименования треклиста: \(appError)")
            toastManager.handle(appError)
        } catch {
            print("❌ Ошибка переименования треклиста: \(error)")
            toastManager.handle(AppError.trackListSaveFailed)
        }
    }

    /// Возвращает название без внешних пробелов и переводов строк.
    private func trimmedName() -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
