//
//  MainNavigationViewModel.swift
//  TrackList
//
//  Состояние корневой навигации для compact- и regular-компоновок.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Combine
import SwiftUI

/// Пункт боковой панели, включая detail-маршрут конкретного треклиста.
enum MainSidebarSelection: Hashable {
    case player
    case library
    case search
    case settings
    case allTrackLists
    case trackList(UUID)
}

/// Хранит выбор корневой навигации и сохраняет совместимость с ScenePhaseHandler.
@MainActor
final class MainNavigationViewModel: ObservableObject {

    // MARK: - Состояние

    /// Текущий пункт боковой панели; конкретный треклист остаётся внутренним маршрутом раздела.
    @Published private(set) var sidebarSelection: MainSidebarSelection

    // MARK: - Зависимости

    /// Существующий глобальный владелец активной основной вкладки.
    private let scenePhaseHandler: ScenePhaseHandler
    /// Подписка принимает внешние переключения разделов без дублирования состояния.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    /// Создаёт ViewModel с глобальным владельцем активной вкладки внутри MainActor-контекста.
    convenience init() {
        self.init(scenePhaseHandler: ScenePhaseHandler.shared)
    }

    /// Позволяет явно передать владельца вкладки при изолированной сборке ViewModel.
    init(scenePhaseHandler: ScenePhaseHandler) {
        self.scenePhaseHandler = scenePhaseHandler
        self.sidebarSelection = Self.sidebarSelection(for: scenePhaseHandler.activeTab)

        scenePhaseHandler.$activeTab
            .removeDuplicates()
            .sink { [weak self] tab in
                self?.applyExternalTab(tab)
            }
            .store(in: &cancellables)
    }

    // MARK: - Связи SwiftUI

    /// Передаёт выбор TabView через единственный существующий источник activeTab.
    var tabSelection: Binding<ScenePhaseHandler.Tab> {
        Binding(
            get: { [weak self] in
                self?.scenePhaseHandler.activeTab ?? .library
            },
            set: { [weak self] tab in
                self?.scenePhaseHandler.activeTab = tab
            }
        )
    }

    /// Принимает выбор List и направляет его через ViewModel, а не через правила в строках.
    var sidebarSelectionBinding: Binding<MainSidebarSelection?> {
        Binding(
            get: { [weak self] in
                self?.sidebarSelection
            },
            set: { [weak self] selection in
                guard let selection else {
                    return
                }

                self?.selectSidebarItem(selection)
            }
        )
    }

    /// Текущая основная вкладка нужна только для presentation-логики MiniPlayer.
    var activeTab: ScenePhaseHandler.Tab {
        scenePhaseHandler.activeTab
    }

    // MARK: - Маршрутизация

    /// Обрабатывает выбор боковой панели и синхронизирует соответствующую основную вкладку.
    private func selectSidebarItem(_ selection: MainSidebarSelection) {
        if sidebarSelection != selection {
            sidebarSelection = selection
        }

        let tab = Self.tab(for: selection)
        if scenePhaseHandler.activeTab != tab {
            scenePhaseHandler.activeTab = tab
        }
    }

    /// Применяет внешний запрос к activeTab, сбрасывая detail треклиста к основному списку.
    private func applyExternalTab(_ tab: ScenePhaseHandler.Tab) {
        let selection = Self.sidebarSelection(for: tab)
        if sidebarSelection != selection {
            sidebarSelection = selection
        }
    }

    /// Сопоставляет глобальную вкладку с основным пунктом боковой панели.
    private static func sidebarSelection(
        for tab: ScenePhaseHandler.Tab
    ) -> MainSidebarSelection {
        switch tab {
        case .player:
            .player
        case .library:
            .library
        case .tracklists:
            .allTrackLists
        case .settings:
            .settings
        case .search:
            .search
        }
    }

    /// Преобразует detail-маршрут треклиста в существующую основную вкладку треклистов.
    private static func tab(
        for selection: MainSidebarSelection
    ) -> ScenePhaseHandler.Tab {
        switch selection {
        case .player:
            .player
        case .library:
            .library
        case .search:
            .search
        case .settings:
            .settings
        case .allTrackLists, .trackList:
            .tracklists
        }
    }
}
