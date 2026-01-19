//
//  RenameTrackListSheet.swift
//  TrackList
//
//  Экран переименования треклиста.
//  Чистая UI-форма ввода имени.
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct RenameTrackListSheet: View {

    let trackListId: UUID
    let currentName: String

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(trackListId: UUID, currentName: String) {
        self.trackListId = trackListId
        self.currentName = currentName
        self._name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                List {
                    Section {
                        TextField("Новое название", text: $name)
                            .clearable($name)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollDisabled(true)
                .navigationTitle("Переименовать треклист")
                .navigationBarTitleDisplayMode(.inline)

                HStack(spacing: 16) {
                    Button {
                        Task {
                            await rename()
                        }
                    } label: {
                        Text("Сохранить")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                    .disabled(!TrackListManager.shared.validateName(name))
                    .opacity(TrackListManager.shared.validateName(name) ? 1 : 0.5)

                    Button {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryButtonStyle()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func rename() async {
        do {
            try await AppCommandExecutor.shared.renameTrackList(
                trackListId: trackListId,
                newName: name
            )
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Ошибка переименования треклиста: \(error.localizedDescription)")
        }
    }
}
