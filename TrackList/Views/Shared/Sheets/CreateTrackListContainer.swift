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

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Новый треклист",
            rightButtonImage: nil,
            isRightEnabled: .constant(false),
            onClose: {
                SheetManager.shared.closeActive()
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
                }
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

        SheetManager.shared.closeActive()
    }

    /// Открывает выбор треков для создания треклиста после подтверждения.
    private func openSelectionForCreate() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard TrackListManager.shared.validateName(trimmedName) else {
            ToastManager.shared.handle(AppError.trackListNameInvalid)
            return
        }

        SheetManager.shared.presentNewTrackListSelectionForCreate(
            name: trimmedName
        )
    }
}
