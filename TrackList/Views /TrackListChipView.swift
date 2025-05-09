//
//  TrackListChipView.swift
//  TrackList
//
//  Чип-вью для одного плейлиста
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation
import SwiftUI

struct TrackListChipView: View {
    let trackList: TrackList
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void

    var body: some View {
        Text(trackList.name)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected
                          ? Color.blue
                          : Color.gray.opacity(0.3))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .onTapGesture { onSelect() }
            .contextMenu {
                Button("Добавить трек", action: onAdd)
                Button("Переименовать") { /* пока пусто */ }
                Button(role: .destructive) { /* пока пусто */ } label: {
                    Text("Удалить")
                }
            }
    }
}
