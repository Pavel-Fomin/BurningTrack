//
//  TrackListLibraryView.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct TrackListLibraryView: View {
    @State private var trackLists: [TrackListMeta] = []

    var body: some View {
        List {
            ForEach(trackLists) { meta in
                NavigationLink(destination: LibraryTrackListDetailView(trackListId: meta.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meta.name)
                            .font(.headline)
                        Text(formattedDate(meta.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            trackLists = TrackListManager.shared
                .loadTrackListMetas()
                .filter { !$0.isDraft } // только сохранённые
        }
        .onAppear {
            let metas = TrackListManager.shared.loadTrackListMetas()
            print("📂 Загрузка треклистов: \(metas.count) найдено")
            for meta in metas {
                print("🧠 \(meta.name) | черновик: \(meta.isDraft)")
            }

            trackLists = metas.filter { !$0.isDraft }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        return formatter.string(from: date)
    }
    
    
}
