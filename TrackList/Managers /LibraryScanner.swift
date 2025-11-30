//
//  LibraryScanner.swift
//  TrackList
//
//  Модуль сканирования файловой системы.
//  Не зависит от TrackRegistry, MusicLibraryManager, UI.
//  Работает только с URL и FileManager.
//
//  Created by Pavel Fomin on 30.11.2025.
//

import Foundation

// MARK: - Результаты сканирования

struct ScannedFolder {
    let url: URL
    let name: String
    let subfolders: [URL]        // Прямые подпапки
    let audioFiles: [URL]        // Прямые аудиофайлы
}

struct ScannedAudioFile: Hashable {
    let url: URL
    let fileName: String
    let folderURL: URL
}

// MARK: - Дельты (понадобятся позже)

enum FileChange {
    case added(URL)
    case removed(URL)
    case moved(old: URL, new: URL)
}

// MARK: - Протокол сканера

protocol LibraryScannerProtocol {
    func scanFolder(_ url: URL) async -> ScannedFolder
    func scanRecursively(_ url: URL) async -> [ScannedAudioFile]
    func diff(old: [ScannedAudioFile], new: [ScannedAudioFile]) -> [FileChange]
}

// MARK: - Реализация

final class LibraryScanner: LibraryScannerProtocol {
    
    private let allowedExtensions = ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"]
    private let fm = FileManager.default
    
    // MARK: - Сканирование одной папки (без рекурсии)
    
    func scanFolder(_ url: URL) async -> ScannedFolder {
        var subfolders: [URL] = []
        var audioFiles: [URL] = []
        
        let items = (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        print("📡 SCAN FOLDER RAW:", url.lastPathComponent,
              "items:", items.count)
        
        for item in items {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            
            if isDir {
                subfolders.append(item)
            } else {
                let ext = item.pathExtension.lowercased()
                if allowedExtensions.contains(ext) {
                    audioFiles.append(item)
                }
            }
        }
        
        return ScannedFolder(
            url: url,
            name: url.lastPathComponent,
            subfolders: subfolders,
            audioFiles: audioFiles
        )
    }
    
    // MARK: - Полный рекурсивный обход
    
    func scanRecursively(_ url: URL) async -> [ScannedAudioFile] {
        var result: [ScannedAudioFile] = []
        var stack: [URL] = [url]
        
        while let current = stack.popLast() {
            let items = (try? fm.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for item in items {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if isDir {
                    stack.append(item)
                } else {
                    let ext = item.pathExtension.lowercased()
                    if allowedExtensions.contains(ext) {
                        result.append(
                            ScannedAudioFile(
                                url: item,
                                fileName: item.lastPathComponent,
                                folderURL: current
                            )
                        )
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Diff между списками файлов
    
    func diff(old: [ScannedAudioFile], new: [ScannedAudioFile]) -> [FileChange] {
        var changes: [FileChange] = []
        
        let oldSet = Set(old)
        let newSet = Set(new)
        
        // Добавленные
        for file in newSet.subtracting(oldSet) {
            changes.append(.added(file.url))
        }
        
        // Удалённые
        for file in oldSet.subtracting(newSet) {
            changes.append(.removed(file.url))
        }
        
        // Мувы (упрощённая логика: совпадает fileName, отличается folderURL)
        let oldByName = Dictionary(grouping: old, by: { $0.fileName })
        let newByName = Dictionary(grouping: new, by: { $0.fileName })
        
        for (name, oldFiles) in oldByName {
            guard let newFiles = newByName[name] else { continue }
            
            for oldItem in oldFiles {
                for newItem in newFiles {
                    if oldItem.url != newItem.url {
                        changes.append(.moved(old: oldItem.url, new: newItem.url))
                    }
                }
            }
        }
        
        return changes
    }
}
