//
//  ScenePhaseHandler.swift
//  TrackList
//
//  Отвечает за глобальное состояние вкладок приложения (TabView)
//  — хранит активную вкладку, обрабатывает повторный выбор,
//  — уведомляет экраны при смене или повторном выборе.
//
//  Created by Pavel Fomin on 02.11.2025.
//

import Foundation
import Combine

@MainActor
final class ScenePhaseHandler: ObservableObject {
    static let shared = ScenePhaseHandler()

    // MARK: - Все вкладки приложения
    enum Tab: Hashable {
        case player
        case library
        case tracklists
        case settings
    }

    // MARK: - Публикуемые состояния
    @Published var activeTab: Tab = .library {
        didSet {
            if oldValue == activeTab {
                repeatedTabSelection = activeTab
                print("🔁 Повторное нажатие на вкладку: \(activeTab)")

                // 🧩 Сбрасываем только при повторном тапе на вкладку треклистов
                if activeTab == .tracklists {
                    NavigationCoordinator.shared.triggerTrackListsReset()
                }
            } else {
                repeatedTabSelection = nil
                print("🧭 Переключились на вкладку: \(activeTab)")
            }
        }
    }

    @Published var repeatedTabSelection: Tab? = nil

    private init() {}
}
