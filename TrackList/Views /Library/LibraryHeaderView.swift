//
//  LibraryHeaderView.swift
//  TrackList
//
//  Заголовок раздела “Фонотека”
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct LibraryHeaderView: View {
    @Binding var selectedTab: Int
    var onAddFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Фонотека")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onAddFolder) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Picker("Раздел", selection: $selectedTab) {
                Text("Музыка").tag(0)
                Text("Треклисты").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}
