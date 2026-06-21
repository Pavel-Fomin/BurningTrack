//
//  LibraryTracksSheetCoordinator.swift
//  TrackList
//
//  Принимает решения по sheet-сценариям экрана треков фонотеки.
//
//  Created by Pavel Fomin on 22.06.2026.
//

/// Координирует экранные реакции фонотеки на жизненный цикл sheet.
@MainActor
struct LibraryTracksSheetCoordinator {

    /// Определяет, нужно ли обновить список после закрытия sheet.
    func shouldRefreshAfterDismiss(
        lastDismissedSheetKind: AppSheetKind?,
        isLoading: Bool
    ) -> Bool {
        guard lastDismissedSheetKind != .batchFilenameRename else { return false }
        guard !isLoading else { return false }

        return true
    }

    /// Определяет, нужно ли открыть sheet массового переименования файлов.
    func shouldPresentBatchFilenameRename(
        isActive: Bool
    ) -> Bool {
        isActive
    }
}
