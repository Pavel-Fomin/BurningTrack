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
    case loadingMetadata  /// Метаданные выбранных треков ещё загружаются.
    case editing          /// Форма готова к редактированию.
}
