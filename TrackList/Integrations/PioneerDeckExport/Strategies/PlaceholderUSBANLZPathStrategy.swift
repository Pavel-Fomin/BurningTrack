//
//  PlaceholderUSBANLZPathStrategy.swift
//  TrackList
//
//  Временная стратегия построения путей USBANLZ.
//

import Foundation

/// Стратегия построения путей ANLZ-файлов внутри папки PIONEER.
public protocol PioneerUSBANLZPathStrategy: Sendable {
    /// Возвращает относительную директорию ANLZ внутри PIONEER.
    func anlzDirectoryRelativePath(for trackId: UInt32) -> String

    /// Возвращает путь к DAT-файлу анализа для записи в PDB scaffold.
    func analyzePathForPDB(trackId: UInt32) -> String
}

/// Временная стратегия построения путей USBANLZ.
///
/// Алгоритм Pioneer/AlphaTheta для папок USBANLZ пока не зареверсен.
/// Текущая реализация существует только для построения стабильной тестовой структуры каталогов.
public struct PlaceholderUSBANLZPathStrategy: PioneerUSBANLZPathStrategy {
    /// Создаёт временную стратегию путей USBANLZ.
    public init() {}

    /// Возвращает placeholder-директорию ANLZ внутри PIONEER.
    public func anlzDirectoryRelativePath(for trackId: UInt32) -> String {
        Self.placeholderANLZDirectoryRelativePath(for: trackId)
    }

    /// Возвращает placeholder-путь DAT-файла для scaffold PDB.
    public func analyzePathForPDB(trackId: UInt32) -> String {
        Self.placeholderAnalyzePathForPDB(trackId: trackId)
    }

    /// Строит placeholder-директорию без создания экземпляра стратегии.
    static func placeholderANLZDirectoryRelativePath(for trackId: UInt32) -> String {
        let bucket = max(1, ((trackId - 1) / 1_000) + 1)
        return String(format: "USBANLZ/P%03u/%08X", bucket, trackId)
    }

    /// Строит placeholder-путь DAT-файла без создания экземпляра стратегии.
    static func placeholderAnalyzePathForPDB(trackId: UInt32) -> String {
        "/PIONEER/\(placeholderANLZDirectoryRelativePath(for: trackId))/ANLZ0000.DAT"
    }
}

/// Валидирует относительные пути внутри PIONEER без знания реального Pioneer layout.
enum PioneerExportPathSanitizer {
    /// Переводит путь export-модели в путь относительно PIONEER.
    static func relativeFilePathInsidePioneer(_ usbPath: String) throws -> String {
        let trimmed = usbPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty, !trimmed.contains("..") else {
            throw PioneerDeckExportError.invalidUSBPath(usbPath)
        }
        return trimmed
    }
}
