//
//  PlayerHeaderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct PlayerHeaderView: View {
    var trackCount: Int
    var onSave: () -> Void
    var onExport: () -> Void
    var onClear: () -> Void
    var onSaveTrackList: () -> Void

    var body: some View {
        ScreenHeaderView(title: "Плеер") {
            EmptyView()
        } trailing: {
            Menu {
                Button("Сохранить треклист", action: onSaveTrackList)
                Button("Записать треклист", action: onExport)
                Button("Очистить треклист", role: .destructive, action: onClear)
            } label: {
                Image(systemName: "ellipsis")
                    .headerIconStyle()
            }
        }
    }
}
