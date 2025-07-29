//
//  View+If.swift
//  TrackList
//
//  Поддержка модификатора `.if` для View
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
