//
//  View+SheetStyle.swift
//  TrackList
//
//  Модификатор стиля sheet
//
//  Created by Pavel Fomin on 07.12.2025.
//

import Foundation
import SwiftUI

extension View {
    func sheetStyle(_ detents: [PresentationDetent]) -> some View {
        self
            .presentationDetents(Set(detents))
            .presentationBackground(.thinMaterial)
    }
}
