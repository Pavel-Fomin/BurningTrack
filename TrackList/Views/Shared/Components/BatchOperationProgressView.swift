//
//  BatchOperationProgressView.swift
//  TrackList
//
//  Компонент прогресса длительной массовой операции.
//
//  Created by Codex on 26.05.2026.
//

import SwiftUI

/// Показывает прогресс длительной массовой операции.
struct BatchOperationProgressView: View {
    let title: String
    let processedCount: Int
    let totalCount: Int
    let message: String?

    init(
        title: String,
        processedCount: Int,
        totalCount: Int,
        message: String? = nil
    ) {
        self.title = title
        self.processedCount = processedCount
        self.totalCount = totalCount
        self.message = message
    }

    private var progressText: String {
        SharedPresentationText.operationProgress(
            processedCount: processedCount,
            totalCount: totalCount
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()

            Text(title)
                .font(.headline)

            Text(progressText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
