//
//  TrackListApp.swift
//  TrackList
//
//  файл запуска SwiftUI-приложения
//  PlayerViewModel() — управляет воспроизведением
//
//  Created by Pavel Fomin on 28.04.2025.
//


import SwiftUI

@main
struct TrackListApp: App {
    
    let playerViewModel: PlayerViewModel

    /// Глобальная ViewModel сохраняет экспорт при смене вкладок и закрытии picker-а.
    @StateObject private var exportProgressViewModel: ExportProgressViewModel
    
    init() {
        do {
            // Открываем постоянное SQLite-хранилище один раз при старте приложения.
            try AppDatabase.shared.open()
        } catch {
            // Инфраструктура БД критична для следующих фаз, поэтому ошибка должна быть заметна сразу.
            preconditionFailure("Не удалось подготовить SQLite-хранилище: \(error.localizedDescription)")
        }

        let playerVM = PlayerViewModel() // без аргументов
        self.playerViewModel = playerVM
        // Фабрика скрывает внутреннюю последовательность сборки export feature.
        let exportFeatureFactory = ExportFeatureFactory()
        _exportProgressViewModel = StateObject(
            wrappedValue: exportFeatureFactory.makeExportProgressViewModel()
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel
            )
            .environmentObject(SheetManager.shared)
            .environmentObject(exportProgressViewModel)
        }
    }
}
