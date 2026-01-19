//
//  View+HeaderStyle.swift
//  TrackList
//
//  Стили для компонентов хедера
//
//  Created by Pavel Fomin on 19.07.2025.
//

import Foundation
import SwiftUI

extension View {
    
    // Унифицированный стиль иконки в заголовке экрана
    func headerIconStyle() -> some View {
        self
            .font(.title3)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}
