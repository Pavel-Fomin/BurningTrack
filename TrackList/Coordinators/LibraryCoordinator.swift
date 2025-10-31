//
//  LibraryCoordinator.swift
//  TrackList
//
//  Отвечает за навигацию внутри раздела «Фонотека»
//  Управляет переходами между корнем, папками и списком треков
//  Подход: MVVM-C (Navigation без enum)
//
//  Created by Pavel Fomin on 25.10.2025.
//

import Foundation
import Combine

@MainActor
final class LibraryCoordinator: ObservableObject {
    enum NavigationState: Hashable {
        case root
        case folder(LibraryFolder)
        case tracks(LibraryFolder)
    }

    @Published private(set) var state: NavigationState = .root
    @Published var pendingRevealTrackURL: URL? = nil

    // MARK: - Навигация

    func openFolder(_ folder: LibraryFolder) {
        // если уже открыта эта папка — не дублируем переход
        if case .folder(let current) = state,
           current.url.standardizedFileURL == folder.url.standardizedFileURL {
            print("⚠️ [Coordinator] Папка уже открыта:", folder.name)
            return
        }

        print("📂 Открываем папку:", folder.name)
        state = .folder(folder)
    }

    func openTracks(for folder: LibraryFolder) {
        print("🎵 Открываем треки для папки: \(folder.name)")
        state = .tracks(folder)
    }

    func goBack() {
        switch state {
        case .tracks(let folder):
            // назад со страницы треков — в папку
            state = .folder(folder)
        case .folder:
            // назад из папки — в корень
            state = .root
        default:
            print("🔙 Уже на корне — возврат невозможен")
        }
    }

    func resetToRoot() {
        print("🏠 Возврат в корень фонотеки")
        state = .root
    }

    // MARK: - Reveal переход (из плеера или треклиста)

    func revealTrack(at url: URL, in folders: [LibraryFolder]) async {
        let folderURL = url.deletingLastPathComponent()

        // Не сбрасываемся в root без нужды
        if let current = currentFolder, current.url == folderURL {
            pendingRevealTrackURL = url
            return
        }

        // Если нужно, открываем нужную папку
        pendingRevealTrackURL = url

        await LibraryNavigationHelper().openContainingFolder(
            for: url,
            in: folders,
            using: self
        )
    }

    // MARK: - Вспомогательное свойство

    var currentFolder: LibraryFolder? {
        switch state {
        case .folder(let f): return f
        case .tracks(let f): return f
        default: return nil
        }
    }
}
