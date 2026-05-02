//
//  TrackSelectableSectionsView.swift
//  TrackList
//
//  Базовый список треков с поддержкой мультиселекта.
//  Не содержит логики плеера, шитов и других зависимостей.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

struct TrackSelectableSectionsView: View {

    // MARK: - Input

    /// Секции треков (уже сгруппированные)
    let sections: [TrackSection]

    /// Выбранные треки
    @Binding var selection: Set<UUID>
    
    /// Провайдер runtime snapshot
    let metadataProvider: TrackMetadataProviding

    // MARK: - UI

    var body: some View {
        ForEach(sections, id: \.id) { section in
            Section {
                ForEach(section.tracks, id: \.id) { track in

                    TrackSelectableRowWrapper(
                        track: track,
                        isSelected: selection.contains(track.id),
                        metadataProvider: metadataProvider,
                        onToggleSelection: {
                            if selection.contains(track.id) {
                                selection.remove(track.id)
                            } else {
                                selection.insert(track.id)
                            }
                        }
                    )
                }
            } header: {

                // Заголовок секции (если есть)
                if !section.title.isEmpty {
                    Text(section.title)
                }
            }
        }
    }
}
