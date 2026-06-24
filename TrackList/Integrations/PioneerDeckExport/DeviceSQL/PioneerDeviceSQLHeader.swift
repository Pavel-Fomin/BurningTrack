//
//  PioneerDeviceSQLHeader.swift
//  TrackList
//
//  Header legacy DeviceSQL export.pdb.
//

import Foundation

/// Константы и поля первой страницы DeviceSQL-файла.
struct PioneerDeviceSQLHeader: Equatable {
    /// Размер страницы, который использует rekordbox export.pdb.
    static let pageSize = 4_096

    /// Смещение table pointers внутри первой страницы.
    static let tableDirectoryOffset = 0x1c

    /// Размер одного table pointer.
    static let tableDescriptorSize = 16

    /// Первое неизвестное поле; в известных export.pdb равно нулю.
    let unknownSignature: UInt32

    /// Размер страницы.
    let pageSize: UInt32

    /// Количество table pointer записей.
    let tableCount: UInt32

    /// Индекс первой неиспользованной страницы, то есть страница сразу за концом файла.
    let nextUnusedPage: UInt32

    /// Неизвестное поле header offset 0x10; reference rekordbox export.pdb пишет 1.
    let unknown: UInt32

    /// TODO(DeviceSQL): подтвердить политику sequence; пока ставим следующий номер после записанных страниц.
    let sequence: UInt32

    /// Создаёт header для нового DeviceSQL-файла.
    init(tableCount: Int, nextUnusedPage: UInt32, sequence: UInt32) {
        self.unknownSignature = 0
        self.pageSize = UInt32(Self.pageSize)
        self.tableCount = UInt32(tableCount)
        self.nextUnusedPage = nextUnusedPage
        self.unknown = 1
        self.sequence = sequence
    }
}
