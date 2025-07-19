//
//  MiniPlayerHeightPreferenceKey.swift
//  TrackList
//
//  Created by Pavel Fomin on 09.07.2025.
//

import SwiftUI
import Foundation

struct MiniPlayerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
