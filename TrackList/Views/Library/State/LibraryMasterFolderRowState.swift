//
//  LibraryMasterFolderRowState.swift
//  TrackList
//
//  Состояние строки прикреплённой папки на корневом экране фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct LibraryMasterFolderRowState: Identifiable {
    /// Идентификатор папки для SwiftUI и навигации.
    let id: UUID
    /// Название папки, отображаемое в списке.
    let name: String
    /// URL папки, нужный для команд прикрепления и открепления.
    let url: URL
    /// Идёт ли сейчас прикрепление и сканирование этой папки.
    let isAttaching: Bool
}
