//
//  ScrollSpeedModel.swift
//  TrackList
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation
import Combine

enum ScrollSpeedState { case slow, fast }

final class ScrollSpeedModel: ObservableObject {
    @Published private(set) var state: ScrollSpeedState = .slow

    var isFast: Bool { state == .fast }
    
    private let threshold: CGFloat       // pt/сек
    private let debounceMs: Int
    private var lastSwitchToSlow: DispatchTime = .now()

    init(thresholdPtPerSec: CGFloat = 1500, debounceMs: Int = 180) {
        self.threshold = thresholdPtPerSec
        self.debounceMs = debounceMs
    }

    /// Сообщаем текущую скорость (pt/сек) — модель сама решит, FAST или SLOW
    func report(velocityAbs: CGFloat) {
        if velocityAbs >= threshold {
            state = .fast
        } else {
            // гистерезис: возвращаемся в slow только если удерживаемся ниже порога некоторое время
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
