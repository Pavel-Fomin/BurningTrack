//
//  ArtworkPurpose.swift
//  TrackList
//
//  Назначение обложки трека
//  - является доменным контрактом
//  - не содержит размеров
//  - не зависит от UI-реализаций
//  - используется ArtworkProvider'ом
//
//  Created by PavelFomin on 08.01.2026.
//


import Foundation

enum ArtworkPurpose: Hashable, CaseIterable {

    // Обложка для списков треков
    /// - фонотека
    /// - треклист
    /// - список треков в плеере
    case trackList

    // Обложка для миниплеера
    case miniPlayer

    // Обложка для sheet «о треке»
    case trackInfoSheet

    /// Preview обложки в форме массового редактирования тегов.
    case batchTagPreview

    // Обложка для toast
    case toast

    // Обложка для системного Now Playing.
    /// - Lock Screen
    /// - Control Center
    case nowPlaying

    /// Полный набор назначений нужен для проверки распределения канонических классов размера.
    static var allCases: [ArtworkPurpose] {
        [
            .trackList,
            .miniPlayer,
            .trackInfoSheet,
            .batchTagPreview,
            .toast,
            .nowPlaying
        ]
    }

    /// Относит назначение к одному из двух канонических подготовленных изображений.
    var sizeClass: ArtworkSizeClass {
        switch self {
        case .trackList, .miniPlayer, .batchTagPreview, .toast:
            .small
        case .trackInfoSheet, .nowPlaying:
            .large
        }
    }
}
