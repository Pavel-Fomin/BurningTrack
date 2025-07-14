//
//  TrackListLibraryView.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct TrackListLibraryView: View {
    let playerViewModel: PlayerViewModel 
    @State private var trackLists: [TrackListMeta] = []
    @State private var path: [UUID] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(trackLists) { meta in
                    NavigationLink(value: meta.id) {
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
            .navigationDestination(for: UUID.self) { id in
                Group {
                    if let meta = trackLists.first(where: { $0.id == id }) {
                        let viewModel = TrackListViewModel()

                        TrackListView(
                            trackListViewModel: viewModel,
                            playerViewModel: playerViewModel
                        )
                        .onAppear {
                            playerViewModel.trackListViewModel = viewModel
                            viewModel.selectTrackList(id: meta.id)
                        }
                    } else {
                        Text("Плейлист не найден")
                    }
                }
            }
            
            .onAppear {
                let metas = TrackListManager.shared.loadTrackListMetas().filter { !$0.isDraft }
                print("📂 Загрузка треклистов: \(metas.count) найдено")
                for meta in metas {
                    print("🧠 \(meta.name) | черновик: \(meta.isDraft)")
                }
                trackLists = metas
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        return formatter.string(from: date)
    }
    
}
