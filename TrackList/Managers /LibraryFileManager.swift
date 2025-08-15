//
//  LibraryFileManager.swift
//  TrackList
//
//  Отвечает за низкоуровневые операции папками:
//  - переименование, удаление, копирование, перемещение
//  - не знает о треках, UI или модели приложения
//
//  Created by Pavel Fomin on 13.08.2025.
//

import Foundation

final class LibraryFileManager {
    static let shared = LibraryFileManager()
    private let fileManager = FileManager.default

    private init() {}

// MARK: - Создание папки

    /// Создаёт новую подпапку в указанной директории
    func createFolder(at parentURL: URL, named folderName: String) -> Result<URL, Error> {
        let newFolderURL = parentURL.appendingPathComponent(folderName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
            return .success(newFolderURL)
        } catch {
            return .failure(error)
        }
    }

// MARK: - Переименование

    /// Переименовывает папку
    func renameItem(at url: URL, to newName: String) -> Result<URL, Error> {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try fileManager.moveItem(at: url, to: newURL)
            return .success(newURL)
        } catch {
            return .failure(error)
        }
    }

// MARK: - Перемещение

    /// Перемещает папку
    func moveItem(from sourceURL: URL, to destinationURL: URL) -> Result<Void, Error> {
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

// MARK: - Удаление

    /// Удаляет файл или папку рекурсивно
    /// UI обязан запросить подтверждение у пользователя ДО вызова метода
    func deleteItem(at url: URL) -> Result<Void, Error> {
        do {
            try fileManager.removeItem(at: url)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

// MARK: - Копирование

    /// Копирует папку в новое место
    func copyItem(from sourceURL: URL, to destinationURL: URL) -> Result<Void, Error> {
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

// MARK: - Проверка на папку

    /// Проверяет, является ли указанный путь папкой
    func isFolder(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

// MARK: - Проверка существования

    /// Проверяет, существует ли папка
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

// MARK: - Содержимое папки

    /// Возвращает список содержимого папки
    func contentsOfDirectory(at url: URL) -> Result<[URL], Error> {
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return .success(contents)
        } catch {
            return .failure(error)
        }
    }
}
