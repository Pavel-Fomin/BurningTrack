//
//  ChipAnimations.swift
//  TrackList
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

extension Animation {
    static let chipSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7,
        blendDuration: 0.1
    )

    static let chipEditMode = Animation.default
}
