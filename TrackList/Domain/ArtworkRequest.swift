//
//  ArtworkRequest.swift
//  TrackList
//
//  Лёгкий запрос на асинхронную подготовку обложки.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Описывает исходные данные и назначение обложки без запуска декодирования.
struct ArtworkRequest: Equatable {
    /// Идентификатор физического трека нужен для явной связи запроса с владельцем данных.
    let trackId: UUID
    /// Стабильная идентичность исходных байтов объединяет кэш и задачу для всех экранов.
    let sourceIdentifier: ArtworkSourceIdentifier
    /// Сырые данные передаются в подсистему подготовки без обработки во View.
    let artworkData: Data?
    /// Назначение определяет доменный класс размера подготовленной обложки.
    let purpose: ArtworkPurpose
    /// Ревизия snapshot сохраняет связь запроса с актуальным состоянием владельца данных.
    let revision: Date?

    /// Создаёт запрос для сохранённой обложки трека.
    init(
        trackId: UUID,
        artworkData: Data?,
        purpose: ArtworkPurpose,
        sourceIdentifier: ArtworkSourceIdentifier,
        revision: Date? = nil
    ) {
        self.trackId = trackId
        self.sourceIdentifier = sourceIdentifier
        self.artworkData = artworkData
        self.purpose = purpose
        self.revision = revision
    }

    /// Канонический класс размера определяется только общим доменным распределением purpose.
    var sizeClass: ArtworkSizeClass {
        purpose.sizeClass
    }

    /// Идентификатор подписки не сравнивает потенциально большие бинарные данные на главном потоке.
    var loadIdentifier: ArtworkLoadIdentifier {
        ArtworkLoadIdentifier(
            sourceIdentifier: sourceIdentifier,
            sizeClass: sizeClass
        )
    }

    /// Сравнение запросов выполняется только по лёгкому идентификатору подписки.
    static func == (lhs: ArtworkRequest, rhs: ArtworkRequest) -> Bool {
        lhs.loadIdentifier == rhs.loadIdentifier
    }
}

extension ArtworkRequest {
    /// Создаёт запрос встроенной обложки из каноничного runtime snapshot.
    init?(
        trackId: UUID,
        snapshot: TrackRuntimeSnapshot?,
        purpose: ArtworkPurpose
    ) {
        guard let snapshot,
              let artworkData = snapshot.artworkData,
              let sourceIdentifier = snapshot.artworkSourceIdentifier else {
            return nil
        }

        self.init(
            trackId: trackId,
            artworkData: artworkData,
            purpose: purpose,
            sourceIdentifier: sourceIdentifier,
            revision: snapshot.updatedAt
        )
    }
}

/// Лёгкий идентификатор одной SwiftUI-подписки на подготовленную обложку.
struct ArtworkLoadIdentifier: Equatable {
    let sourceIdentifier: ArtworkSourceIdentifier
    let sizeClass: ArtworkSizeClass
}
