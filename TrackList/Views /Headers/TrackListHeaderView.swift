//
//  TrackListHeaderView.swift
//  TrackList
//
//  Хедер для экрана треклиста
//
//  Created by Pavel Fomin on 06.11.2025.
//

import SwiftUI

struct TrackListHeaderView: View {
    @ObservedObject var viewModel: TrackListViewModel
    var onExport: () -> Void
    var onRename: () -> Void

    var body: some View {
           ScreenHeaderView(
               title: viewModel.name.isEmpty ? "Без названия" : viewModel.name
           ) {
               EmptyView()
           } trailing: {
               Menu {
                   Button("Экспортировать треки", action: onExport)
                   Button("Переименовать", action: onRename)
               } label: {
                   Image(systemName: "ellipsis")
                       .headerIconStyle()
               }
           }
       }
   }
