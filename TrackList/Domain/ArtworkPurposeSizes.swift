//
//  ArtworkPurposeSizes.swift
//  TrackList
//
//  Целевые размеры обложек для каждого назначения.
//  Любое изменение значений в этом файле считается изменением доменного контракта проекта.
//
//  - размеры являются ИНВАРИАНТАМИ проекта
//  - не зависят от UI, экранов и компонентов
//  - не подлежат вычислению или изменению в рантайме
//  - единственный источник истины для ArtworkProvider
//
//  Created by PavelFomin on 09.01.2026.
//

import Foundation

enum ArtworkPurposeSizes {

    // Возвращает целевой максимальный размер обложки для заданного назначения.
    static func maxPixel(for purpose: ArtworkPurpose) -> Int {
        switch purpose {

        /// Списки треков
        case .trackList: return 96

        /// Toast с информацией о треке
        case .toast: return 48

        /// Миниплеер
        case .miniPlayer: return 96

        /// Sheet «о треке»
        case .trackInfoSheet: return 320

        /// Lock Screen / Control Center
        case .nowPlaying: return 512
        }
    }
}
