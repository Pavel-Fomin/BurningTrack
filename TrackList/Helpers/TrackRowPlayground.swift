//
//  TrackRowPlayground.swift
//  TrackList
//
//  Локальная площадка для ручной проверки вариантов отображения строки трека.
//
//  Created by Pavel Fomin on 25.04.2025.
//

import SwiftUI

struct TrackRowPlayground: View {
    var body: some View {
        List {
            Section("Обычные треки") {
                ForEach(0..<3) { _ in
                }
            }
            Section("Текущий трек") {
            }
            Section("Экспортируется") {
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
