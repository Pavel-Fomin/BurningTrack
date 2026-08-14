//
//  Haptics.swift
//  TrackList
//
//  Инкапсулирует подготовку и воспроизведение тактильной обратной связи устройства.
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

    func lightTap() {
        DispatchQueue.main.async {
            self.lightGen?.impactOccurred()
        }
    }

    func warmup() {
        DispatchQueue.main.async {
            self.lightGen?.prepare()
        }
    }
}
