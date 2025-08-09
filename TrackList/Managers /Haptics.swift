//
//  Haptics.swift
//  TrackList
//
//  Created by Pavel Fomin on 10.08.2025.
//

import Foundation
import UIKit
import CoreHaptics

final class Haptics {
    static let shared = Haptics()
    private init() {}

    private lazy var lightGen: UIImpactFeedbackGenerator? = {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
        #endif
    }()

    /// вызывать только с main
    func lightTap() {
        DispatchQueue.main.async {
            self.lightGen?.impactOccurred()
        }
    }

    /// звать, когда экран стал активным (например, в onAppear корневого вью)
    func warmup() {
        DispatchQueue.main.async {
            self.lightGen?.prepare()
        }
    }
}
