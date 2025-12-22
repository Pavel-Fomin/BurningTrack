//
//  AddToTrackListSheet.swift
//  TrackList
//
//  Экран выбора треклиста для добавления трека.
//  Является UI-формой и не содержит бизнес-логики.
//
//  При выборе треклиста инициирует команду через AppCommandExecutor
//  и закрывается самостоятельно.
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

struct AddToTrackListSheet: View {

    // MARK: - Входные параметры

    let track: any TrackDisplayable

    // MARK: - Состояние

    @Environment(\.dismiss) private var dismiss

    private let trackLists = TrackListsManager.shared.loadTrackListMetas()  /// Список треклистов — read-only данные для UI

    // MARK: - UI

    var body: some View {
        List(trackLists) { meta in
            Button {
                Task {
                    await addTrack(to: meta.id)
                }
            } label: {
                HStack {
                    Text(meta.name)
                        .lineLimit(1)

                    Spacer()

                    let count = TrackListManager.shared
                        .getTrackListById(meta.id)
                        .tracks.count

                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle("Добавить в треклист")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Вспомогательные методы

private extension AddToTrackListSheet {

    /// Инициирует команду добавления трека в треклист.
    func addTrack(to trackListId: UUID) async {
        do {
            try await AppCommandExecutor.shared.addTrackToTrackList(
                trackId: track.id,
                trackListId: trackListId
            )

            /// После выполнения команды закрываем sheet
            await MainActor.run {
                dismiss()
            }

        } catch {
            print("❌ Ошибка добавления трека в треклист: \(error.localizedDescription)")
        }
    }
}
