//
//  GlobalBottomScrollReserveModifier.swift
//  TrackList
//
//  Централизованный резерв прокрутки под глобальный высокий MiniPlayer.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import SwiftUI

/// Хранит единственные глобальные значения нижней геометрии приложения.
enum GlobalBottomGeometry {
    /// Резерв позволяет последним строкам подняться выше высокого MiniPlayer.
    static let miniPlayerScrollReserve: CGFloat = 240
}

/// Передаёт активный резерв от MainTabView к прокручиваемому содержимому вкладок.
private struct GlobalBottomScrollReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Текущий резерв равен нулю, когда глобальный MiniPlayer скрыт.
    var globalBottomScrollReserve: CGFloat {
        get { self[GlobalBottomScrollReserveKey.self] }
        set { self[GlobalBottomScrollReserveKey.self] = newValue }
    }
}

/// Применяет резерв только к области прокрутки, не добавляя строки или внешний padding.
private struct GlobalBottomScrollReserveModifier: ViewModifier {
    /// Значение поступает от единственного владельца глобальной нижней геометрии.
    @Environment(\.globalBottomScrollReserve) private var reserve

    /// Нулевой резерв не переопределяет системные content margins экрана.
    @ViewBuilder
    func body(content: Content) -> some View {
        if reserve > 0 {
            content.contentMargins(
                .bottom,
                reserve,
                for: .scrollContent
            )
        } else {
            content
        }
    }
}

extension View {
    /// Подключает прокручиваемый контейнер к глобальному резерву MainTabView.
    func globalBottomScrollReserve() -> some View {
        modifier(GlobalBottomScrollReserveModifier())
    }
}
