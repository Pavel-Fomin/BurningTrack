//
//  ToastData.swift
//  TrackList
//
//  Модель данных для отображения тоста при добавлении трека.
//  Содержит краткую информацию о треке и сообщение.
//
//  Created by Pavel Fomin on 08.07.2025.
//

import Foundation
import SwiftUI

struct ToastData: Identifiable, Equatable {
    let id: UUID = UUID()   
    let title: String?       // Название трека
    let artist: String?     // Исполнитель
    let artwork: UIImage?   // Обложка
    let message: String     // Сообщение (например, "добавлен в плеер")
}
