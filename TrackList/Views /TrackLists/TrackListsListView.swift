//
//  TrackListsListView.swift
//  TrackList
//
//  Cписок треклистов
//
//  Created by Pavel Fomin on 18.07.2025.
//

import Foundation
import SwiftUI

struct TrackListsListView: View {
    @State private var trackListToDelete: TrackList? = nil
    @State private var showDeleteAlert = false
    @ObservedObject var viewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    
    
    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.trackLists) { list in
                    trackListRow(for: list)
                }
            }
            .onAppear { viewModel.refreshTrackLists() }
            .listStyle(.insetGrouped)
        }
        .alert(
            "Удалить треклист\n«\(trackListToDelete?.name ?? "")»?",
            isPresented: $showDeleteAlert,
            presenting: trackListToDelete
        ) { list in
            Button("Удалить", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.deleteTrackList(id: list.id)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Треклист удалится безвозвратно")
        }
    }
    
    @ViewBuilder
    private func trackListRow(for list: TrackList) -> some View {
        NavigationLink(
            destination: TrackListScreen(trackList: list, playerViewModel: playerViewModel)
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.body)
                        .fontWeight(.regular)
                    Text("\(list.tracks.count) треков")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                trackListToDelete = list
                showDeleteAlert = true
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
