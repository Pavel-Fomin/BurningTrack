//
//  Styles.swift
//  TrackList
//
//  Created by Pavel Fomin on 24.04.2025.
//


import Foundation
import SwiftUI

// MARK: - HEX Color Extension
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// Общие стили для текста в приложении
enum Fonts {
    static let title = Font.system(size: 24, weight: .bold, design: .default)
    static let trackArtist = Font.system(size: 16, weight: .medium, design: .default)
    static let trackTitle = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let button = Font.system(size: 16, weight: .semibold, design: .default)
}

/// Палитра цветов в HEX
enum Palette {
    static let black = Color(hex: "#000000")
    static let gray = Color(hex: "#8E8E93")
    static let white = Color(hex: "#FFFFFF")
    static let blue = Color(hex: "#007AFF")
    static let orange = Color(hex: "#FF9500")
}

/// Цвета приложения
enum Colors {
    static let primaryText = Palette.black
    static let secondaryText = Palette.gray
    static let background = Palette.white
    static let accent = Palette.blue
    static let exportingIndicator = Palette.orange
}

/// Отступы
enum Spacing {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
}

/// Системные иконки приложения
enum Icons {
    static let addTrack = Image(systemName: "plus")
    static let record = Image(systemName: "record.circle")
    static let export = Image(systemName: "laser.burst")
    static let clear = Image(systemName: "wand.and.sparkles")
    static let play = Image(systemName: "play.fill")
    static let pause = Image(systemName: "pause.fill")
    static let next = Image(systemName: "forward.fill")
    static let previous = Image(systemName: "backward.fill")
    static let airplay = Image(systemName: "airplayaudio")
}

// MARK: - View Modifiers

/// Стиль для названия трека
struct TrackTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Fonts.trackTitle)
            .foregroundColor(Colors.primaryText)
    }
}

/// Стиль для имени исполнителя
struct TrackArtistStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Fonts.trackArtist)
            .foregroundColor(Colors.secondaryText)
    }
}

/// Стиль для заголовков (например, "TRACKLIST")
struct HeaderTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Fonts.title)
            .foregroundColor(Colors.primaryText)
    }
}

/// Стиль для кнопок
struct ButtonTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Fonts.button)
            .foregroundColor(Colors.accent)
    }
}


/// Стиль для строки в списке треков
struct TrackRowStyle: ViewModifier {
    var isCurrent: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, Spacing.medium)
            .background(isCurrent ? Colors.accent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle()) // Добавлено для растяжки подсветки по всей строке
            .cornerRadius(12)
            .shadow(color: Colors.secondaryText.opacity(0.1), radius: isCurrent ? 4 : 0)
    }
}

// MARK: - View Extensions

extension View {
    func trackTitleStyle() -> some View {
        self.modifier(TrackTitleStyle())
    }

    func trackArtistStyle() -> some View {
        self.modifier(TrackArtistStyle())
    }

    func headerTitleStyle() -> some View {
        self.modifier(HeaderTitleStyle())
    }

    func buttonTextStyle() -> some View {
        self.modifier(ButtonTextStyle())
    }

    func trackRowStyle(isCurrent: Bool) -> some View {
        self.modifier(TrackRowStyle(isCurrent: isCurrent))
    }
}
