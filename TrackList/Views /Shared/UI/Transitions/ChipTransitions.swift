//
//  ChipTransitions.swift
//  TrackList
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

extension AnyTransition {
    static var chipInsertion: AnyTransition {
        .scale.combined(with: .opacity)
    }

    static var chipRemoval: AnyTransition {
        .opacity.combined(with: .scale)
    }

    static var chipAppearDisappear: AnyTransition {
        .asymmetric(insertion: .chipInsertion, removal: .chipRemoval)
    }
}
