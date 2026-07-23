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

/// Фаза подтверждения открепления выбранной папки.
enum LibraryMasterDetachFolderConfirmation {
    /// Подтверждение не показывается.
    case none
    /// Пользователь должен подтвердить обычное открепление папки.
    case detachFolder
    /// Пользователь должен остановить воспроизведение перед откреплением папки.
    case stopPlayback
}

struct LibraryMasterScreenState {
    /// Состояние восстановления доступа к фонотеке.
    let accessState: MusicLibraryManager.LibraryAccessState
    /// Строки прикреплённых папок.
    let folders: [LibraryMasterFolderRowState]
    /// Нужно ли показывать отдельный источник купленных iTunes-треков.
    let showsPurchasedITunesSource: Bool
    /// Нужно ли показывать пустое состояние.
    let isEmpty: Bool
    /// Текущая фаза подтверждения открепления папки.
    let detachFolderConfirmation: LibraryMasterDetachFolderConfirmation

    /// Нужно ли показать обязательное подтверждение обычного открепления папки.
    var showsDetachFolderConfirmation: Bool {
        detachFolderConfirmation == .detachFolder
    }

    /// Нужно ли показать предупреждение перед откреплением папки с активным треком.
    var folderContainsPlayingTrack: Bool {
        detachFolderConfirmation == .stopPlayback
    }
}
