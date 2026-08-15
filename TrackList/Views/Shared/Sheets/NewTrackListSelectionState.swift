//
//  NewTrackListSelectionState.swift
//  TrackList
//
//  Состояние sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct NewTrackListSelectionState {
    /// Готовый снимок прикреплённых папок для корневого списка выбора.
    let folders: [LibraryFolder]
    /// Количество выбранных треков для presentation-элементов экрана.
    let selectedCount: Int
    /// Идентификаторы выбранных треков для готового presentation-state дочерних папок.
    let selectedTrackIDs: Set<UUID>
    /// Можно ли применить текущий выбор треков.
    let canSubmit: Bool
    /// Выполняется ли создание или добавление выбранных треков.
    let isSubmitting: Bool
}
