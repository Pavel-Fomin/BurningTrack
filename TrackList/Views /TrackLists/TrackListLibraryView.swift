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
    @State private var trackListToDelete: TrackListMeta?
    
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            trackListToDelete = meta
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .confirmationDialog(
                                "Удалить треклист \"\(trackListToDelete?.name ?? "")\"?",
                                isPresented: Binding(
                                    get: { trackListToDelete != nil },
                                    set: { if !$0 { trackListToDelete = nil } }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button("Удалить", role: .destructive) {
                                    if let toDelete = trackListToDelete {
                                        TrackListManager.shared.deleteTrackList(id: toDelete.id)
                                        trackLists.removeAll { $0.id == toDelete.id }
                                        trackListToDelete = nil
                                    }
                                }
                                Button("Отмена", role: .cancel) {
                                    trackListToDelete = nil
                                
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
                            viewModel.selectTrackList(id: meta.id)
                        }
                    } else {
                        Text("Плейлист не найден")
                    }
                }
            }
            
            .onAppear {
                let metas = TrackListManager.shared.loadTrackListMetas()
                print("📂 Загрузка треклистов: \(metas.count) найдено")
                for meta in metas {
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
