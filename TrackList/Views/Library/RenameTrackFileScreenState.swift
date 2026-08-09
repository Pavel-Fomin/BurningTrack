//
//  RenameTrackFileScreenState.swift
//  TrackList
//
//  Presentation-state sheet-flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Готовое состояние формы без ссылок на domain- или infrastructure-зависимости.
struct RenameTrackFileScreenState: Equatable {
    /// Текущее значение поля ручного имени файла.
    let fileName: String
    /// Доступно ли подтверждение переименования.
    let isRenameEnabled: Bool
    /// Выполняется ли сохранение имени файла.
    let isProcessing: Bool
    /// Единственный взаимоисключающий системный alert текущего flow.
    let alert: RenameTrackFileAlert?
}

/// Причина alert, которую форма может отобразить пользователю.
enum RenameTrackFileAlert: Equatable {
    /// Файл удерживается текущим воспроизведением.
    case stopPlayback
    /// В папке уже существует файл с целевым именем.
    case fileNameConflict
}
