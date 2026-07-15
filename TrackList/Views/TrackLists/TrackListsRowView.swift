//
//  TrackListsRowView.swift
//  TrackList
//
//  Общий внешний вид строки списка треклистов.
//  Created by Pavel Fomin on 07.07.2026.
//

import SwiftUI

struct TrackListsRowView: View {
    let title: String
    let createdAtText: String
    let tracksCountText: String
    let onTap: () -> Void

    init(
        row: TrackListsRowState,
        onTap: @escaping () -> Void
    ) {
        self.title = row.title
        self.createdAtText = row.createdAtText
        self.tracksCountText = row.tracksCountText
        self.onTap = onTap
    }

    init(
        title: String,
        createdAtText: String,
        tracksCountText: String,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.createdAtText = createdAtText
        self.tracksCountText = tracksCountText
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(createdAtText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(tracksCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
