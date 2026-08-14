//
//  BatchTagFieldEditState.swift
//  TrackList
//
//  UI-состояние одного поля в форме массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

struct BatchTagFieldEditState: Identifiable, Equatable {
    
    let field: EditableTrackField
    var action: BatchTagFieldEditAction
    var value: String
    let summary: BatchTagFieldSummary
    var id: EditableTrackField { field
    }
}
