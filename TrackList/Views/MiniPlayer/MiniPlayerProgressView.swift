//
//  MiniPlayerProgressView.swift
//  TrackList
//
//  Нижняя часть мини-плеера (прогресс).
//
//  Роль:
//  - отображает текущее время и оставшееся время
//  - отображает прогресс-бар
//  - выполняет seek при перемотке
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI

struct MiniPlayerProgressView: View {

    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            Text(formatTimeSmart(currentTime))
                .font(.caption2)
                .frame(width: 40, alignment: .leading)

            ProgressBar(
                progress: {
                    let ratio = duration > 0 ? currentTime / duration : 0
                    return ratio
                }(),
                onSeek: { ratio in
                    let newTime = ratio * duration
                    onSeek(newTime)
                },
                height: 10
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            Text("-\(formatTimeSmart(duration - currentTime))")
                .font(.caption2)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.top, 8)
    }
}
