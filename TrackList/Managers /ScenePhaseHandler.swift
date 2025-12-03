//
//  ScenePhaseHandler.swift
//  TrackList
//
//  Глобальный менеджер вкладок (TabView):
//  — хранит активную вкладку,
//  — фиксирует повторный выбор вкладки,
//  — уведомляет экраны о смене или повторном нажатии.
//
//  Не занимается маршрутизацией внутри разделов.
//  Внутренняя навигация фонотеки — в NavigationCoordinator.
//
//  Created by Pavel Fomin on 02.11.2025.
//

import Foundation
import Combine

@MainActor
final class ScenePhaseHandler: ObservableObject {

    static let shared = ScenePhaseHandler()
    private init() {}

    enum Tab: Hashable {
        case player
        case library
        case tracklists
        case settings
        case search
    }

    @Published var activeTab: Tab = .library
}
