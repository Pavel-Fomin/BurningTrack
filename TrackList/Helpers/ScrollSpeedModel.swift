//
//  ScrollSpeedModel.swift
//  TrackList
//
//  Хранит пороговое состояние скорости прокрутки для облегчения тяжёлого представления.
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation
import Combine

enum ScrollSpeedState { case slow, fast }

/// Скорость прокрутки является transient UI-state и изменяется только владельцем MainActor.
@MainActor
final class ScrollSpeedModel: ObservableObject {
    @Published private(set) var state: ScrollSpeedState = .slow

    var isFast: Bool { state == .fast }
    
    private let threshold: CGFloat
    private let debounceMs: Int
    private var lastSwitchToSlow: DispatchTime = .now()

    init(thresholdPtPerSec: CGFloat = 1500, debounceMs: Int = 180) {
        self.threshold = thresholdPtPerSec
        self.debounceMs = debounceMs
    }

    func report(velocityAbs: CGFloat) {
        if velocityAbs >= threshold {
            state = .fast
        } else {
            // Гистерезис предотвращает переключение состояния на каждом пересечении порога.
            if state == .fast {
                let now = DispatchTime.now()
                if now.uptimeNanoseconds - lastSwitchToSlow.uptimeNanoseconds > UInt64(debounceMs) * 1_000_000 {
                    state = .slow
                }
            } else {
                state = .slow
            }
            lastSwitchToSlow = .now()
        }
    }
}
