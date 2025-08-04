//
//  ToastData.swift
//  TrackList
//
//  МУниверсальная модель для отображения тостов
//
//  Created by Pavel Fomin on 08.07.2025.
//

import Foundation
import SwiftUI

struct ToastData: Identifiable, Equatable {
    enum Style {
        case track(title: String, artist: String)
        case trackList(name: String)
    }

    let id: UUID = UUID()
    let style: Style
    let artwork: UIImage?

    var message: String {
        switch style {
        case .track: return "Добавлен в плеер"
        case .trackList(let name): return "Треклист «\(name)» сохранён"
        }
    }

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.style == rhs.style
    }
}

extension ToastData.Style: Equatable {}
