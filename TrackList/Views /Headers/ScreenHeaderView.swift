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
import UIKit

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
            ZStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack {
                    leading()
                        .frame(width: 32, height: 44, alignment: .leading)

                    Spacer()

                    trailing()
                        .frame(width: 32,height: 44, alignment: .trailing)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
        
        }
    }
