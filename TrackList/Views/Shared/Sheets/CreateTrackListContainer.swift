//
//  CreateTrackListContainer.swift
//  TrackList
//
//  Контейнер создания нового треклиста.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI
import Foundation

struct CreateTrackListContainer: View {

    // MARK: - State

    /// Название нового треклиста.
    @State private var name = generateDefaultTrackListName()

    /// Фокус поля имени для управления клавиатурой из контейнера.
    @FocusState private var isNameFocused: Bool

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Новый треклист",
            rightButtonImage: nil,
            isRightEnabled: .constant(false),
            onClose: {
                closeSheet()
            }
        ) {
            CreateTrackListSheet(
                name: $name,
                canSubmit: TrackListManager.shared.validateName(name),
                onAddTracks: {
                    openSelectionForCreate()
                },
                onAddLater: {
                    createEmptyTrackList()
                },
                isNameFocused: $isNameFocused
            )
        }
    }
    
    // MARK: - Actions

    /// Создаёт пустой треклист и закрывает sheet.
    private func createEmptyTrackList() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard TrackListManager.shared.validateName(trimmedName) else {
            ToastManager.shared.handle(AppError.trackListNameInvalid)
            return
        }

        do {
            let created = try TrackListsManager.shared.createEmptyTrackList(withName: trimmedName)
            ToastManager.shared.handle(.trackListCreated(name: created.name))
        } catch let appError as AppError {
            PersistentLogger.log("CreateTrackListContainer: create empty tracklist failed error=\(appError)")
            ToastManager.shared.handle(appError)
            return
        } catch {
            PersistentLogger.log("CreateTrackListContainer: create empty tracklist failed error=\(error)")
            ToastManager.shared.handle(AppError.trackListSaveFailed)
            return
        }

        closeSheet()
    }

    /// Открывает выбор треков для создания треклиста после подтверждения.
    private func openSelectionForCreate() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard TrackListManager.shared.validateName(trimmedName) else {
            ToastManager.shared.handle(AppError.trackListNameInvalid)
            return
        }

        presentTrackSelectionSheet(name: trimmedName)
    }

    /// Закрывает sheet после предварительного снятия фокуса с поля ввода.
    private func closeSheet() {
        isNameFocused = false
        SheetManager.shared.closeActive()
    }

    /// Переключает текущий sheet на выбор треков после предварительного снятия фокуса.
    private func presentTrackSelectionSheet(name: String) {
        isNameFocused = false
        SheetManager.shared.presentNewTrackListSelectionForCreate(
            name: name
        )
    }
}
