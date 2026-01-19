//
//  TrackDisplayable.swift
//  TrackList
//
//  Универсальный протокол для отображения треков в списке
//
//  Created by Pavel Fomin on 05.07.2025.
//

import UIKit

// MARK: -  Протокол

protocol TrackDisplayable: Identifiable {
    var id: UUID { get }

    // Показываемое имя файла
    var fileName: String { get }

    // Метаданные
    var title: String? { get }
    var artist: String? { get }
    var duration: Double { get }
    var artwork: UIImage? { get }

    // Флаг доступности
    var isAvailable: Bool { get }
}
