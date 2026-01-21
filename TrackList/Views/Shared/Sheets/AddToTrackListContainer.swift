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

    /// Данные, переданные через SheetManager.
    /// Содержат трек и контекст открытия (sourceTrackListId).
    let data: AddToTrackListSheetData

    // MARK: - State

    /// Выбранный пользователем треклист назначения.
    /// Источник истины для UI и для кнопки подтверждения (✓).
    @State private var selectedTrackListId: UUID?

    // MARK: - Data source

    /// Список всех треклистов в том же порядке,
    /// в каком они отображаются в основном списке треклистов.
    /// Порядок фиксируется здесь и не вычисляется внутри sheet’а.
    private let trackLists: [TrackListsManager.TrackListMeta] =
        TrackListsManager.shared
            .loadTrackListMetas()
            .sorted { $0.createdAt > $1.createdAt }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Добавить в треклист",

            /// Кнопка подтверждения (✓) активна только если:
            /// - выбран треклист
            /// - выбранный треклист отличается от исходного
            isRightEnabled: Binding(
                get: {
                    selectedTrackListId != nil &&
                    selectedTrackListId != data.sourceTrackListId
                },
                set: { _ in }
            ),

            /// Закрытие sheet’а без выполнения действий
            onClose: { SheetManager.shared.closeActive()
            },

            /// Подтверждение добавления трека
            onConfirm: { Task { await addTrack() }
            }
        ) {
            /// Чистый UI-компонент.
            /// Получает данные и binding, но не содержит логики.
            AddToTrackListSheet(
                trackLists: trackLists,
                currentTrackListId: data.sourceTrackListId,
                selectedTrackListId: $selectedTrackListId
            )
        }
    }

    // MARK: - Actions

    /// Выполняет команду добавления трека в выбранный треклист.
    /// При успешном выполнении закрывает sheet.
    private func addTrack() async {
        guard let trackListId = selectedTrackListId else { return }

        do {
            try await AppCommandExecutor.shared.addTrackToTrackList(
                trackId: data.track.id,
                trackListId: trackListId
            )
            SheetManager.shared.closeActive()
        } catch {
            // Ошибки пока логируются.
            // UI-обработка ошибок может быть добавлена централизованно позже.
            print("❌ Ошибка добавления трека в треклист: \(error)")
        }
    }
}
