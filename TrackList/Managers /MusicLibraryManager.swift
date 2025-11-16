//
//  MusicLibraryManager.swift
//  TrackList
//
//  Управляет доступом к прикреплённым папкам фонотеки, сканированием аудиофайлов и восстановлением доступа
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine
import AVFoundation
import UIKit

@MainActor
final class MusicLibraryManager: ObservableObject {

    static let shared = MusicLibraryManager()

    // MARK: - Published состояния

    @Published private(set) var isAccessRestored = false
    @Published var attachedFolders: [LibraryFolder] = []
    @Published var folderURL: URL?
    @Published var rootFolder: LibraryFolder?
    @Published var tracks: [URL] = []


    // MARK: - Инициализация

    init() {
        Task.detached(priority: .background) { [weak self] in
            await self?.restoreAccessAsync()
        }
    }


    // MARK: - Ленивая модель папки

    func liteFolder(from url: URL) -> LibraryFolder {
        LibraryFolder(
            name: url.lastPathComponent,
            url: url,
            subfolders: [],
            audioFiles: []
        )
    }


    // MARK: - Полное дерево папки

    func buildFolderTree(from folderURL: URL) -> LibraryFolder {
        let fm = FileManager.default
        let name = folderURL.lastPathComponent

        var subfolders: [LibraryFolder] = []
        var audioFiles: [URL] = []

        if let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for item in contents {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    subfolders.append(buildFolderTree(from: item))
                } else {
                    let ext = item.pathExtension.lowercased()
                    if ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"].contains(ext) {
                        audioFiles.append(item)
                    }
                }
            }
        }

        return LibraryFolder(
            name: name,
            url: folderURL,
            subfolders: subfolders,
            audioFiles: audioFiles
        )
    }


    // MARK: - Сохраняем bookmark выбранной папки и регистрируем её

    func saveBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Не удалось начать доступ к папке")
            return
        }

        Task {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let bookmarkData = try url.bookmarkData()
                let bookmarkBase64 = bookmarkData.base64EncodedString()

                let folderId = url.libraryFolderId
                let name = url.lastPathComponent
                let path = url.path

                await TrackRegistry.shared.registerFolder(
                    folderId: folderId,
                    name: name,
                    path: path,
                    bookmarkBase64: bookmarkBase64
                )

                await MainActor.run {
                    self.folderURL = url
                    if self.attachedFolders.contains(where: { $0.url == url }) == false {
                        self.attachedFolders.append(self.liteFolder(from: url))
                    }
                }

                print("📁 Папка добавлена: \(name)")

            } catch {
                print("❌ Не удалось создать bookmarkData: \(error)")
            }
        }
    }


    // MARK: - Восстановление прикреплённых папок через TrackRegistry

    func restoreAccessAsync() async {
        print("🔁 Восстановление доступа к папкам…")

        await TrackRegistry.shared.load()

        let folders = await TrackRegistry.shared.foldersList()

        if folders.isEmpty {
            print("ℹ️ Нет сохранённых папок")
            await MainActor.run { self.isAccessRestored = true }
            return
        }

        var resolvedFolders: [LibraryFolder] = []

        for folder in folders {
            guard
                let data = Data(base64Encoded: folder.bookmarkBase64)
            else { continue }

            var stale = false

            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )

                if stale {
                    print("⚠️ Bookmark устарел: \(folder.name)")
                }

                if url.startAccessingSecurityScopedResource() {
                    let tree = buildFolderTree(from: url)
                    resolvedFolders.append(tree)
                    print("✅ Доступ к папке: \(folder.name)")
                } else {
                    print("⚠️ Ошибка доступа к папке: \(folder.name)")
                }

            } catch {
                print("❌ Ошибка восстановления bookmark: \(error)")
            }
        }

        await MainActor.run {
            self.attachedFolders = resolvedFolders
            self.isAccessRestored = true
        }

        print("✅ Восстановление доступа завершено")
    }


    // MARK: - Асинхронная генерация LibraryTrack

    func generateLibraryTracks(from urls: [URL], folderId: UUID) async -> [LibraryTrack] {
        await withTaskGroup(of: LibraryTrack?.self) { group in
            for url in urls {
                group.addTask {

                    let trackId = await TrackRegistry.shared.trackId(for: url)

                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                    let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let addedDate = values?.creationDate ??
                                    values?.contentModificationDate ??
                                    Date()

                    let metadata = try? await MetadataParser.parseMetadata(from: url)

                    let bookmarkData = (try? url.bookmarkData()) ?? Data()
                    let bookmarkBase64 = bookmarkData.base64EncodedString()

                    await TrackRegistry.shared.register(
                        trackId: trackId,
                        bookmarkBase64: bookmarkBase64,
                        folderId: folderId,
                        fileName: url.lastPathComponent
                    )

                    let resolved = await TrackRegistry.shared.resolvedURL(for: trackId) ?? url

                    return LibraryTrack(
                        id: trackId,
                        fileURL: url,
                        title: metadata?.title ?? url.deletingPathExtension().lastPathComponent,
                        artist: metadata?.artist,
                        duration: metadata?.duration ?? 0,
                        addedDate: addedDate
                    )
                }
            }

            var result: [LibraryTrack] = []
            for await track in group {
                if let track { result.append(track) }
            }
            return result
        }
    }


    // MARK: - Навигация и выделение трека

    func openFolder(at folderURL: URL, highlight trackURL: URL) async {
        if let idx = attachedFolders.firstIndex(where: { $0.url == folderURL }) {
            NavigationCoordinator.shared.pendingReveal = trackURL
            attachedFolders[idx] = attachedFolders[idx]
        }
    }
}
