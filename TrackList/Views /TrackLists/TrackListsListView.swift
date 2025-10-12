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
    @ObservedObject var viewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    var body: some View {
        List {
            ForEach(viewModel.trackLists) { list in
                trackListRow(for: list)
            }
        }
        .onAppear {
            viewModel.refreshTrackLists()
        
        }
        .listStyle(.insetGrouped)
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteTrackList(id: list.id)
            } label: {
                Image(systemName: "trash")
            }
        }
    }
}
