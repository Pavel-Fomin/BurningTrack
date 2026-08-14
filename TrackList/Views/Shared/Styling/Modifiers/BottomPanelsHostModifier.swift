//
//  BottomPanelsHostModifier.swift
//  TrackList
//
//  Модификаторы глобальных и локальных нижних панелей.
//
//  Роль:
//  - размещает глобальные панели внутри safe area конкретной вкладки;
//  - резервирует собственное место SelectionActionBar локального экрана;
//  - не выполняет действий плеера или выбора;
//  - не хранит состояние панелей.
//
//  Created by Pavel Fomin on 20.05.2026.
//

import SwiftUI

struct GlobalBottomPanelsHostModifier: ViewModifier {

    // MARK: - Входные данные

    /// Использует единый feature graph MiniPlayer, созданный в composition root приложения.
    let miniPlayerFeature: MiniPlayerFeature
    /// Использует общее состояние экспорта без создания локальной операции.
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    /// Передаёт UI-намерения в typed Export-feature ActionHandler.
    @EnvironmentObject private var exportActionHandler: ExportFeatureActionHandler
    /// Управляет только присутствием высокого MiniPlayer в общем контейнере.
    let showsMiniPlayer: Bool

    // MARK: - Содержимое

    func body(content: Content) -> some View {
        let exportProgress = exportProgressViewModel.progress
        let showsExportPanel = exportProgress != nil
        let showsGlobalPanels = showsMiniPlayer || showsExportPanel

        return content
            // Inset применяется внутри ветки TabView и учитывает системное меню вкладок.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsGlobalPanels {
                    BottomPanelsHost(
                        spacing: showsExportPanel && showsMiniPlayer ? 8 : 0,
                        showsTopPanel: showsExportPanel
                    ) {
                        if let exportProgress {
                            ExportProgressCompactView(
                                progress: exportProgress,
                                actionHandler: exportActionHandler
                            )
                            .padding(.horizontal, 8)
                            .transition(
                                .move(edge: .bottom)
                                    .combined(with: .opacity)
                            )
                        }
                    } bottomPanel: {
                        if showsMiniPlayer {
                            MiniPlayerWrapperView(
                                feature: miniPlayerFeature
                            )
                        }
                    }
                    .animation(
                        .easeOut(duration: 0.25),
                        value: showsExportPanel
                    )
                    .animation(
                        .easeOut(duration: 0.25),
                        value: showsMiniPlayer
                    )
                }
            }
    }
}

struct BottomPanelsHostModifier<TopPanel: View>: ViewModifier {

    // MARK: - Входные данные

    let showsTopPanel: Bool
    let topPanel: () -> TopPanel

    // MARK: - Содержимое

    @ViewBuilder
    func body(content: Content) -> some View {
        // Safe area inset остаётся частью одного дерева независимо от видимости панели.
        // Иначе смена верхней панели меняет structural identity content, включая NavigationStack.
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsTopPanel {
                    topPanel()
                        .padding(.horizontal, 8)
                        .animation(.easeOut(duration: 0.25), value: showsTopPanel)
                }
            }
    }
}

// MARK: - Расширение View

extension View {

    /// Подключает общие панели к корню конкретной вкладки.
    func globalBottomPanelsHost(
        miniPlayerFeature: MiniPlayerFeature,
        exportProgressViewModel: ExportProgressViewModel,
        showsMiniPlayer: Bool
    ) -> some View {
        modifier(
            GlobalBottomPanelsHostModifier(
                miniPlayerFeature: miniPlayerFeature,
                exportProgressViewModel: exportProgressViewModel,
                showsMiniPlayer: showsMiniPlayer
            )
        )
    }

    /// Подключает локальную панель конкретного экрана.
    func bottomPanelsHost<TopPanel: View>(
        showsTopPanel: Bool = true,
        @ViewBuilder topPanel: @escaping () -> TopPanel
    ) -> some View {
        modifier(
            BottomPanelsHostModifier(
                showsTopPanel: showsTopPanel,
                topPanel: topPanel
            )
        )
    }
}
