//
//  TrackDisplayable.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import UIKit

// Универсальный протокол для отображения треков в списке
protocol TrackDisplayable: Identifiable {
    var id: UUID { get }
    var title: String? { get }
    var artist: String? { get }
    var artwork: UIImage? { get }
    var duration: Double { get }
    var isAvailable: Bool { get }
    var fileName: String { get }
}
