//
//  LibraryMasterActionOutput.swift
//  TrackList
//
//  Output корневого flow фонотеки.
//  ActionHandler отправляет сюда изменения экранного состояния, не зная конкретную ViewModel.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
protocol LibraryMasterActionOutput: AnyObject {
    /// Папка, ожидающая подтверждения открепления.
    var pendingDetachFolder: LibraryFolder? { get }

    /// Пересобирает состояние корневого экрана.
    func refreshState()

    /// Запоминает папку и показывает обязательное подтверждение её открепления.
    func requestDetachFolderConfirmation(_ folder: LibraryFolder)

    /// Скрывает подтверждение перед окончательным откреплением папки.
    func dismissDetachFolderConfirmation()

    /// Показывает предупреждение об остановке воспроизведения перед откреплением.
    func showPlayingTrackDetachWarning(for folder: LibraryFolder)

    /// Скрывает подтверждения и очищает папку, ожидающую открепления.
    func clearPendingDetachFolder()

    /// Сохраняет ручное перемещение прикреплённой папки.
    func moveFolder(from source: IndexSet, to destination: Int)
}
