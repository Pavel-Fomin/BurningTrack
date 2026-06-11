//
//  BatchTagArtworkSizeFormatter.swift
//  TrackList
//
//  Форматирование размера обложки для массового редактирования тегов.
//
//  Created by Pavel Fomin on 11.06.2026.
//

import Foundation

/// Форматирует размер обложки для отображения в BatchTagEdit.
enum BatchTagArtworkSizeFormatter {
    /// Возвращает читаемый размер обложки.
    static func string(from bytes: Int) -> String {
        guard bytes > 0 else { return "Нет обложки" }
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024.0
        let gigabyte = megabyte * 1024.0
        let value = Double(bytes)
        if value < megabyte {
            return "\(Int(ceil(value / kilobyte))) КБ"
        }
        if value < gigabyte {
            return String(format: "%.1f МБ", value / megabyte)
        }
        return String(format: "%.1f ГБ", value / gigabyte)
    }
}
