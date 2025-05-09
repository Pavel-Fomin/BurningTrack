//
//  Track+Extension.swift
//  TrackList
//
//  Расширение для преобразования ImportedTrack в Track.
//  Используется при загрузке треклиста из JSON, чтобы передать данные в UI и плеер.
//  Здесь происходит декодирование base64-encoded обложки в UIImage.
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

extension ImportedTrack {
    func asTrack() -> Track {
        let url: URL

        do {
            url = try resolvedURL()
            let success = url.startAccessingSecurityScopedResource()
            if !success {

            } else {
                
            }
        } catch {
            print("❌ Ошибка при разрешении bookmark для \(fileName): \(error)")
            url = URL(fileURLWithPath: filePath)
        }

        return Track(
            id: id,
            url: url,
            artist: artist ?? "Неизвестный артист",
            title: title ?? fileName,
            duration: duration,
            fileName: fileName,
            artwork: artworkBase64
                .flatMap { Data(base64Encoded: $0) }
                .flatMap { UIImage(data: $0) }
        )
    }
}
