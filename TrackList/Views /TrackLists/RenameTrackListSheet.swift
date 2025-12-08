//
//  RenameTrackListSheet.swift
//  TrackList
//
//  Sheet "Переименование треклиста"
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct RenameTrackListSheet: View {
    @Binding var isPresented: Bool
    @State private var name: String
    var onRename: (_ newName: String) -> Void
    
    init(isPresented: Binding<Bool>, currentName: String, onRename: @escaping (_ newName: String) -> Void) {
        self._isPresented = isPresented
        self._name = State(initialValue: currentName)
        self.onRename = onRename
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // MARK: - Инпут
                
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
                
                // MARK: - Кнопки
                
                HStack(spacing: 16) {
                    Button {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onRename(trimmed)
                        isPresented = false
                    } label: {
                        Text("Сохранить")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButtonStyle()
                    .disabled(!TrackListManager.shared.validateName(name))
                    .opacity(TrackListManager.shared.validateName(name) ? 1 : 0.5)
                    
                    Button {
                        isPresented = false
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
}
