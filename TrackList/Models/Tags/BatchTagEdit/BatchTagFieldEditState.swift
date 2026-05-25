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
    
    let field: EditableTrackField       /// Поле тега, которое редактируется.
    var action: BatchTagFieldEditAction /// Действие, выбранное пользователем для этого поля.
    var value: String                   /// Новое значение поля.
    let summary: BatchTagFieldSummary   /// Сводная информация о текущих значениях этого поля у выбранных треков.
    var id: EditableTrackField { field  /// Идентификатор для SwiftUI-списков.
    }
}
