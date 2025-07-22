//
//  LibraryHeaderView.swift
//  TrackList
//
//  Заголовок раздела “Фонотека”
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

import SwiftUI

struct LibraryHeaderView: View {
    var onAddFolder: () -> Void

    var body: some View {
        ScreenHeaderView(title: "Фонотека", trailing:  {
            EmptyView()
            
        })
    }
}
