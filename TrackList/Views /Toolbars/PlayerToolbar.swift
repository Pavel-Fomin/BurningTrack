//
//  PlayerToolbar.swift
//  TrackList
//
//  Тулбар для раздела “Плеер”
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct PlayerToolbar: ViewModifier {
    var trackCount: Int
    var onSave: () -> Void
    var onExport: () -> Void
    var onClear: () -> Void
    var onSaveTrackList: () -> Void
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: "Плеер",
                leading: { EmptyView() },
                trailing: {
                    Menu {
                        Button("Сохранить треклист", action: onSaveTrackList)
                        
                        Button(action: onExport) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Записать треклист")
                                Text("с префиксом")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Очистить треклист", role: .destructive, action: onClear)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            )
    }
}

extension View {
    func playerToolbar(
        trackCount: Int,
        onSave: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onSaveTrackList: @escaping () -> Void
    ) -> some View {
        self.modifier(PlayerToolbar(
            trackCount: trackCount,
            onSave: onSave,
            onExport: onExport,
            onClear: onClear,
            onSaveTrackList: onSaveTrackList
        ))
    }
}
