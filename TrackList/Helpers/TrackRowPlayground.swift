//
//  TrackRowPlayground.swift
//  TrackList
//
//  Created by Pavel Fomin on 25.04.2025.
//

import SwiftUI

struct TrackRowPlayground: View {
    var body: some View {
        List {
            Section("Обычные треки") {
                ForEach(0..<3) { _ in
                    // TrackRowView(track: .mock, isPlaying: false, isCurrent: false)
                }
            }
            Section("Текущий трек") {
                // TrackRowView(track: .mock, isPlaying: true, isCurrent: true)
            }
            Section("Экспортируется") {
                // TrackRowView(track: .mockExporting, isPlaying: false, isCurrent: false)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

struct TrackRowPlayground_Previews: PreviewProvider {
    static var previews: some View {
        TrackRowPlayground()
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.light)
        TrackRowPlayground()
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.dark)
    }
}
