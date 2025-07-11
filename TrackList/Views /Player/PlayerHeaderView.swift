//
//  PlayerHeaderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct PlayerHeaderView: View {
    let trackCount: Int
    let onSave: () -> Void
    let onExport: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Плеер")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(trackCount) треков")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                Button("Сохранить треклист", action: onSave)
                Button("Экспортировать", action: onExport)
                Button("Очистить треклист", role: .destructive, action: onClear)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
