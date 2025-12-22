//
//  TrackActionSheet.swift
//  TrackList
//
//  Действия над треком: Показать в фонотеке, Переместить, О треке
//
//  Sheet является UI-компонентом и не содержит логики.
//  При выборе действия инициирует UI-координацию через SheetActionCoordinator.
//
//  Created by Pavel Fomin on 16.09.2025.
//

import Foundation
import SwiftUI

struct TrackActionSheet: View {

    // MARK: - Входные параметры

    let track: any TrackDisplayable
    let context: TrackContext
    let actions: [TrackAction]

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {

            // Используем enumerated, чтобы не требовать Hashable
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: action,
                        track: track,
                        context: context
                    )
                } label: {
                    HStack(spacing: 12) {
                        icon(for: action)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 28)

                        Text(title(for: action))
                            .font(.system(size: 17))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.vertical, 0)
    }

    // MARK: - Локальные helpers

    private func title(for action: TrackAction) -> String {
        switch action {
        case .showInLibrary:
            return "Показать в фонотеке"
        case .moveToFolder:
            return "Переместить"
        case .showInfo:
            return "О треке"
        }
    }

    private func icon(for action: TrackAction) -> Image {
        switch action {
        case .showInLibrary:
            return Image(systemName: "folder")
        case .moveToFolder:
            return Image(systemName: "arrow.right.doc.on.clipboard")
        case .showInfo:
            return Image(systemName: "info.circle")
        }
    }
}
