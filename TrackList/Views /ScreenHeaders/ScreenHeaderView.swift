//
//  ScreenHeaderView.swift
//  TrackList
//
//  Универсальный заголовок для всех разделов
//
//  Created by Pavel Fomin on 18.07.2025.
//

import Foundation
import SwiftUI

struct ScreenHeaderView<Leading: View, Trailing: View>: View {
    let title: String
    let leading: () -> Leading
    let trailing: () -> Trailing

    init(
        title: String,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            leading()
                .frame(width: 32, alignment: .leading)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            trailing()
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}
