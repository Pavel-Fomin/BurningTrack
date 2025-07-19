//
//  PlayerHeaderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

import SwiftUI

struct PlayerHeaderView: View {
    var trackCount: Int
    var onSave: () -> Void
    var onExport: () -> Void
    var onClear: () -> Void

    var body: some View {
        ScreenHeaderView(title: "Плеер") {
            EmptyView()
        } trailing: {
            HStack(spacing: 12) {
                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down")
                }
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
            }
        }
    }
}
