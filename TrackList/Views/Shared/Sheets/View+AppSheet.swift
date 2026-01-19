//
//  View+AppSheet.swift
//  TrackList
//
//  Унифицированное расширение для отображения шитов
//  Оборачивает любой sheet-контент в AppSheetContainer
//  Экран просто вызывает .appSheet(...) и получает единый стиль из AppSheetContainer
//
//  Created by Pavel Fomin on 07.12.2025.
//

import Foundation
import SwiftUI

extension View {
    func appSheet(
        detents: Set<PresentationDetent> = [.medium, .large]
    ) -> some View {
        AppSheetContainer(detents: detents) {
            self
        }
    }
}
