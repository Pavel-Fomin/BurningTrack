//
//  BottomPanelsHost.swift
//  TrackList
//
//  Единый нижний контейнер плавающих панелей.
//
//  Роль:
//  - укладывает нижние UI-панели в одном layout-потоке;
//  - не знает о бизнес-действиях;
//  - не владеет состоянием;
//  - не использует overlay, offset или фиксированные высоты.
//
//  Created by Pavel Fomin on 20.05.2026.
//

import SwiftUI

struct BottomPanelsHost<TopPanel: View, BottomPanel: View>: View {

    // MARK: - Input

    let spacing: CGFloat
    let showsTopPanel: Bool
    let topPanel: TopPanel
    let bottomPanel: BottomPanel

    // MARK: - Init

    init(
        spacing: CGFloat = 0,
        showsTopPanel: Bool = true,
        @ViewBuilder topPanel: () -> TopPanel,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self.spacing = spacing
        self.showsTopPanel = showsTopPanel
        self.topPanel = topPanel()
        self.bottomPanel = bottomPanel()
    }

    // MARK: - UI

    var body: some View {
        VStack(spacing: showsTopPanel ? spacing : 0) {
            if showsTopPanel {
                topPanel
            }
            bottomPanel
        }
        .frame(maxWidth: .infinity)
    }
}
