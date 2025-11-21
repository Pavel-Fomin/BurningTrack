//
//  LibraryNavigationHelper.swift
//  TrackList
//
//  Created by Pavel Fomin on 26.10.2025.
//

import Foundation

struct LibraryNavigationHelper {

    @MainActor
    func openContainingFolder(
        for url: URL,
        in folders: [LibraryFolder],
        using coordinator: LibraryCoordinator
    ) async{
    
    
        let folderURL = url.deletingLastPathComponent()

        guard let folder = Self.findFolder(for: folderURL, in: folders) else {
            print("⚠️ Папка для \(url.lastPathComponent) не найдена")
            return
        }

        print("➡️ Reveal: открываем папку \(folder.name)")

        // Просто открываем нужную папку, без reset’ов и костылей
        coordinator.openFolder(folder)
    }

    static func findFolder(for url: URL, in folders: [LibraryFolder]) -> LibraryFolder? {
        for folder in folders {
            if folder.url.standardizedFileURL == url.standardizedFileURL {
                return folder
            }
            if let found = findFolder(for: url, in: folder.subfolders) {
                return found
            }
        }
        return nil
    }
    func buildPath(to targetURL: URL, in folders: [LibraryFolder]) -> [LibraryFolder]? {
        for folder in folders {
            // Совпала целевая папка — возвращаем её
            if folder.url.standardizedFileURL == targetURL.standardizedFileURL {
                return [folder]
            }

            // Проверяем вложенные подпапки
            if let subpath = buildPath(to: targetURL, in: folder.subfolders) {
                return [folder] + subpath
            }
        }
        return nil
    }
}

