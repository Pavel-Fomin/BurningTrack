//
//  BottomPanelsHostModifier.swift
//  TrackList
//
//  Модификатор единого нижнего контейнера панелей.
//
//  Роль:
//  - резервирует место под реальные нижние панели через safeAreaInset;
//  - размещает верхнюю панель над мини-плеером;
//  - не выполняет действий плеера или мультиселекта;
//  - не хранит состояние панелей.
//
//  Created by Pavel Fomin on 20.05.2026.
//

import SwiftUI

struct BottomPanelsHostModifier<TopPanel: View>: ViewModifier {

    // MARK: - Input

    @ObservedObject var playerViewModel: PlayerViewModel
    /// Читает единое состояние экспорта, не создавая локальную копию на экране.
    @EnvironmentObject private var exportProgressViewModel: ExportProgressViewModel
    let showsTopPanel: Bool
    let showsBottomPanel: Bool
    let topPanel: () -> TopPanel

    // MARK: - Body

    func body(content: Content) -> some View {
        let exportProgress = exportProgressViewModel.progress
        let showsExportPanel = exportProgress != nil

        return content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomPanelsHost(
                    // Оставляем панель экспорта отделённой от мини-плеера в одном layout-потоке.
                    spacing: showsExportPanel && showsBottomPanel ? 8 : 0,
                    showsTopPanel: showsTopPanel || showsExportPanel
                ) {
                    VStack(spacing: 8) {
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

                        if showsTopPanel {
                            topPanel()
                                .padding(.horizontal, 8)
                        }
                    }
                } bottomPanel: {
                    if showsBottomPanel {
                        MiniPlayerWrapperView(
                            playerViewModel: playerViewModel
                        )
                    }
                }
                .animation(
                    .easeOut(duration: 0.25),
                    value: showsExportPanel
                )
                .animation(.easeOut(duration: 0.25), value: showsTopPanel)
                .animation(
                    .easeOut(duration: 0.25),
                    value: playerViewModel.currentTrackDisplayable?.id
                )
            }
    }
}

// MARK: - View extension

extension View {

    /// Подключает единый нижний контейнер панелей к экрану.
    func bottomPanelsHost<TopPanel: View>(
        playerViewModel: PlayerViewModel,
        showsTopPanel: Bool = true,
        showsBottomPanel: Bool = true,
        @ViewBuilder topPanel: @escaping () -> TopPanel
    ) -> some View {
        modifier(
            BottomPanelsHostModifier(
                playerViewModel: playerViewModel,
                showsTopPanel: showsTopPanel,
                showsBottomPanel: showsBottomPanel,
                topPanel: topPanel
            )
        )
    }
}
