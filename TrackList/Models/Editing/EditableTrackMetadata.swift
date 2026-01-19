//
//  EditableTrackMetadata.swift
//  TrackList
//
//  Временная модель для inline-редактирования тегов трека.
//  Хранит значения всех редактируемых полей в строковом виде.
//  Используется только на уровне UI.
//
//  Created by PavelFomin on 19.01.2026.
//
/*
import Foundation

final class EditableTrackMetadata: ObservableObject {
    
    /// Текущие редактируемые значения
    @Published private(set) var values: [FieldId: String]
    
    /// Оригинальные значения (для полного отката)
    private let originalValues: [FieldId: String]
    
    init(initialValues: [FieldId: String]) {
        self.values = initialValues
        self.originalValues = initialValues
    }
    
    /// Обновление значения конкретного поля
    func updateValue(_ value: String, for field: FieldId) {
        values[field] = value
    }
    
    /// Получение значения поля
    func value(for field: FieldId) -> String {
        values[field] ?? ""
    }
    
    /// Откат всех изменений
    func reset() {
        values = originalValues
    }
    
    /// Проверка, изменялось ли поле
    func isModified(_ field: FieldId) -> Bool {
        values[field] != originalValues[field]
    }
}
*/
