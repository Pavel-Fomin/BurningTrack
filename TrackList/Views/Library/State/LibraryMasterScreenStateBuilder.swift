//
//  LibraryMasterScreenStateBuilder.swift
//  TrackList
//
//  Собирает состояние корневого экрана фонотеки из MusicLibraryManager.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct LibraryMasterScreenStateBuilder {

    /// Собирает состояние экрана с учётом текущей папки, ожидающей открепления.
    @MainActor
    func build(
        manager: MusicLibraryManager,
        settings: AppSettings,
        pendingDetachFolder: LibraryFolder?,
        selectedSortMode: LibraryFoldersSortMode?
    ) -> LibraryMasterScreenState {

        let folders = manager.attachedFolders.map { folder in
            LibraryMasterFolderRowState(
                id: folder.id,
                name: folder.name,
                url: folder.url,
                isAttaching: manager.isAttachingFolder(folder.id)
            )
        }

        return LibraryMasterScreenState(
            accessState: manager.accessState,
            folders: folders,
            showsPurchasedITunesSource: settings.visible.library.isPurchasedITunesSourceVisible,
            isEmpty: folders.isEmpty,
            detachAlert: detachAlert(for: pendingDetachFolder),
            selectedSortMode: selectedSortMode,
            sortModeCaption: selectedSortMode?.caption
        )
    }

    /// Собирает предупреждение только тогда, когда открепление требует остановить воспроизведение.
    private func detachAlert(
        for pendingDetachFolder: LibraryFolder?
    ) -> LibraryMasterDetachAlertState? {
        guard pendingDetachFolder != nil else { return nil }

        return LibraryMasterDetachAlertState(
            title: "Чтобы открепить папку, остановите воспроизведение",
            message: "Сейчас воспроизводится трек из этой папки."
        )
    }
}
