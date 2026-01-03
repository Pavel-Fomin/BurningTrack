//
//  SaveTrackListSheet.swift
//  TrackList
//
//  Экран создания нового треклиста.
//  Чистая UI-форма ввода имени.
//
//  Created by Pavel Fomin on 11.07.2025.
//

import SwiftUI

struct SaveTrackListSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                List {
                    Section {
                        TextField("Название", text: $name)
                            .clearable($name)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollDisabled(true)
                .navigationTitle("Сохранить треклист")
                .navigationBarTitleDisplayMode(.inline)
                
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await create()
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
            .onAppear {
                name = generateDefaultTrackListName()
            }
        }
    }
    
    private func create() async {
        do {
            try await AppCommandExecutor.shared.createTrackList(name: name)
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ Ошибка сохранения треклиста: \(error)")
        }
    }
}
