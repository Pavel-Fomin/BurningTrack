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

    // MARK: - Input

    /// Использует общую ViewModel плеера, созданную в composition root приложения.
    @ObservedObject var playerViewModel: PlayerViewModel
    /// Использует общее состояние экспорта без создания локальной операции.
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    /// Управляет только присутствием высокого MiniPlayer в общем контейнере.
    let showsMiniPlayer: Bool

    // MARK: - Body

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
                                onTap: {
                                    exportProgressViewModel.presentDetails()
                                },
                                onDismiss: {
                                    exportProgressViewModel.dismissCompletedExport()
                                }
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
                                playerViewModel: playerViewModel
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
                    .animation(
                        .easeOut(duration: 0.25),
                        value: playerViewModel.currentTrackDisplayable?.id
                    )
                }
            }
    }
}

struct BottomPanelsHostModifier<TopPanel: View>: ViewModifier {

    // MARK: - Input

    let showsTopPanel: Bool
    let topPanel: () -> TopPanel

    // MARK: - Body

    @ViewBuilder
    func body(content: Content) -> some View {
        if showsTopPanel {
            content
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    topPanel()
                        .padding(.horizontal, 8)
                        .animation(.easeOut(duration: 0.25), value: showsTopPanel)
                }
        } else {
            content
        }
    }
}

// MARK: - View extension

extension View {

    /// Подключает общие панели к корню конкретной вкладки.
    func globalBottomPanelsHost(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel,
        showsMiniPlayer: Bool
    ) -> some View {
        modifier(
            GlobalBottomPanelsHostModifier(
                playerViewModel: playerViewModel,
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
