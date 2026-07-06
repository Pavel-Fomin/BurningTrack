//
//  LibraryMasterScreenState.swift
//  TrackList
//
//  Состояние корневого экрана фонотеки.
//  View получает готовые данные и не читает менеджеры напрямую.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct LibraryMasterScreenState {
    /// Состояние восстановления доступа к фонотеке.
    let accessState: MusicLibraryManager.LibraryAccessState
    /// Строки прикреплённых папок.
    let folders: [LibraryMasterFolderRowState]
    /// Нужно ли показывать отдельный источник купленных iTunes-треков.
    let showsPurchasedITunesSource: Bool
    /// Нужно ли показывать пустое состояние.
    let isEmpty: Bool
    /// Состояние предупреждения перед откреплением папки.
    let detachAlert: LibraryMasterDetachAlertState?
    /// Сортировка, выбранная через меню; nil означает ручной порядок без галочки.
    let selectedSortMode: LibraryFoldersSortMode?
    /// Подпись сортировки для меню; nil означает, что caption не показывается.
    let sortModeCaption: String?
}
