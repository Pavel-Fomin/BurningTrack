//
//  EditableTrackField.swift
//  TrackList
//
//  Описание редактируемого поля метаданных трека.
//  Является UI-контрактом для inline-редактирования в TrackDetailSheet.
//  Не содержит логики сохранения.
//
//  Created by PavelFomin on 19.01.2026.
//

import Foundation

/// Тип редактируемого поля
enum EditableTrackFieldKind: Equatable {
    /// Текстовое поле
    /// - multiline: допускает многострочный ввод
    case text(multiline: Bool)

    /// Числовое поле (ввод как String)
    case number
}

/// Описание одного поля метаданных трека
struct EditableTrackField: Identifiable, Equatable {

    /// Уникальный идентификатор поля (универсальный, чтобы UI мог работать с любым enum)
    let id: AnyHashable

    /// Отображаемый лейбл (верхняя строка)
    let title: String

    /// Тип поля и режим ввода
    let kind: EditableTrackFieldKind
}
