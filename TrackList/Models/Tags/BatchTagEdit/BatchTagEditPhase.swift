//
//  BatchTagEditPhase.swift
//  TrackList
//
//  Этап работы формы массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

enum BatchTagEditPhase: Equatable {
    /// Метаданные выбранных треков ещё загружаются.
    case loadingMetadata
    /// Форма готова к редактированию.
    case editing
    /// Теги выбранных треков сохраняются.
    case saving
}
