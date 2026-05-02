//
//  ListRowStyle.swift
//  TrackList
//
//  Унифицированный стиль строк списков.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

extension View {

    /// Стиль строки списка для треков
    func trackListRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}
