//
//  AddToTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана добавления трека в треклист.
//
//  Контейнер выполняет роль координатора:
//  - владеет состоянием выбора (selectedTrackListId)
//  - принимает контекст открытия sheet’а (sourceTrackListId)
//  - управляет кнопками navigation bar (✓ / ×)
//  - выполняет бизнес-команду добавления трека
//
//  ВАЖНО:
//  - контейнер не содержит UI-разметки списка
//  - контейнер не реагирует на tap’ы напрямую
//  - вся визуальная логика вынесена в AddToTrackListSheet
//  - sheet не знает о командах и навигации
//
//  Архитектурный паттерн:
//  NavigationBarHost (UIKit) + чистый SwiftUI sheet
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct AddToTrackListContainer: View {

    // MARK: - Input

    /// Данные, переданные через SheetManager
    let data: AddToTrackListSheetData

    // MARK: - State

    /// Выбранный пользователем треклист назначения
    @State private var selectedTrackListId: UUID?

    // MARK: - Data source

    /// Список всех треклистов в фиксированном порядке
    private let trackLists: [TrackListsManager.TrackListMeta] =
        TrackListsManager.shared
            .loadTrackListMetas()
            .sorted { $0.createdAt > $1.createdAt }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Добавить в треклист",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только если:
            /// - выбран треклист
            /// - он отличается от исходного
            isRightEnabled: Binding(
                get: {
                    selectedTrackListId != nil &&
                    selectedTrackListId != data.sourceTrackListId
                },
                set: { _ in }
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                SheetManager.shared.closeActive()
            },

            /// Подтверждение добавления трека
            onRightTap: {
                Task { await addTrack() }
            }
        ) {
            /// Чистый UI-компонент без логики
            AddToTrackListSheet(
                trackLists: trackLists,
                currentTrackListId: data.sourceTrackListId,
                selectedTrackListId: $selectedTrackListId
            )
        }
    }

    // MARK: - Actions

    /// Добавление трека в выбранный треклист
    private func addTrack() async {
        guard let trackListId = selectedTrackListId else { return }

        do {
            try await AppCommandExecutor.shared.addTrackToTrackList(
                trackId: data.track.id,
                trackListId: trackListId
            )
            SheetManager.shared.closeActive()
        } catch {
            print("❌ Ошибка добавления трека в треклист: \(error)")
        }
    }
}
