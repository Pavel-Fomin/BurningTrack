//
//  PioneerDeckColor.swift
//  TrackList
//
//  Цветовая модель для минимального USB-экспорта Pioneer/AlphaTheta.
//

import Foundation

/// Описывает цвет rekordbox-совместимого справочника.
public struct PioneerDeckColor: Codable, Equatable, Sendable {
    /// Числовой идентификатор цвета внутри export-модели.
    public let id: UInt32

    /// Человекочитаемое имя цвета.
    public let name: String

    /// Красный канал для readback/golden-проверок.
    public let red: UInt8

    /// Зелёный канал для readback/golden-проверок.
    public let green: UInt8

    /// Синий канал для readback/golden-проверок.
    public let blue: UInt8

    /// Создаёт цвет справочника Pioneer/AlphaTheta.
    public init(id: UInt32, name: String, red: UInt8, green: UInt8, blue: UInt8) {
        self.id = id
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Минимальный стабильный набор цветов, соответствующий восьми строкам образца.
    public static let rekordboxDefaults: [PioneerDeckColor] = [
        PioneerDeckColor(id: 1, name: "Pink", red: 255, green: 105, blue: 180),
        PioneerDeckColor(id: 2, name: "Red", red: 220, green: 20, blue: 60),
        PioneerDeckColor(id: 3, name: "Orange", red: 255, green: 140, blue: 0),
        PioneerDeckColor(id: 4, name: "Yellow", red: 255, green: 215, blue: 0),
        PioneerDeckColor(id: 5, name: "Green", red: 50, green: 205, blue: 50),
        PioneerDeckColor(id: 6, name: "Aqua", red: 0, green: 191, blue: 255),
        PioneerDeckColor(id: 7, name: "Blue", red: 65, green: 105, blue: 225),
        PioneerDeckColor(id: 8, name: "Purple", red: 138, green: 43, blue: 226)
    ]
}
