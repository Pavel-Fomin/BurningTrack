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

    /// Показывает предупреждение перед откреплением папки.
    func setPendingDetachFolder(_ folder: LibraryFolder)

    /// Скрывает предупреждение перед откреплением папки.
    func clearPendingDetachFolder()

    /// Применяет выбранную сортировку прикреплённых папок.
    func setSortMode(_ mode: LibraryFoldersSortMode)

    /// Сохраняет ручное перемещение прикреплённой папки.
    func moveFolder(from source: IndexSet, to destination: Int)
}
