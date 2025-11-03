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
    
    private var folderStack: [LibraryFolder] = []         /// Иерархический стек переходов
    @Published private(set) var stateID: UUID = UUID()
    @Published private(set) var state: NavigationState = .root
    @Published var pendingRevealTrackURL: URL? = nil

    // MARK: - Навигация

    func openFolder(_ folder: LibraryFolder) {
        // уже эта же папка — игнор
        if case .folder(let current) = state,
           current.url.standardizedFileURL == folder.url.standardizedFileURL { return }

        // если открываем подпапку текущей
        if let last = folderStack.last,
           folder.url.deletingLastPathComponent().standardizedFileURL == last.url.standardizedFileURL {
            folderStack.append(folder)
        } else {
            // иначе начинаем новую ветку (новый путь)
            folderStack = [folder]
        }

        state = .folder(folder)
        stateID = UUID()
    }

    func goBack() {
        guard !folderStack.isEmpty else {
            state = .root
            return
        }

        _ = folderStack.popLast() // удалить текущую папку

        if let last = folderStack.last {
            // есть родитель → возвращаемся к нему
            state = .folder(last)
        } else {
            // иначе возвращаемся в корень
            state = .root
        }
    }

    func resetToRoot() {
        folderStack.removeAll()
        state = .root
    }
    
    
    // MARK: - Reveal переход (из плеера или треклиста)

    func revealTrack(at url: URL, in folders: [LibraryFolder]) async {
        let folderURL = url.deletingLastPathComponent()

        // Если уже открыта нужная папка — просто передаём сигнал
        if let current = currentFolder,
           current.url.standardizedFileURL == folderURL.standardizedFileURL {
            pendingRevealTrackURL = url
            return
        }

        // Найдём цепочку всех родительских папок до нужной
        if let fullPath = LibraryNavigationHelper().buildPath(to: folderURL, in: folders) {
            folderStack = fullPath               // 💥 вот ключ — мы восстанавливаем стек
            if let last = fullPath.last {
                state = .folder(last)
                pendingRevealTrackURL = url
            }
        } else {
            print("⚠️ [Reveal] Не удалось найти путь к папке:", folderURL.lastPathComponent)
        }
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
