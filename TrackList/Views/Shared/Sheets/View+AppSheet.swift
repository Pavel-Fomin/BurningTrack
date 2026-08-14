//
//  View+AppSheet.swift
//  TrackList
//
//  Применяет единый presentation-стиль sheet без хранения его route или lifecycle.
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
