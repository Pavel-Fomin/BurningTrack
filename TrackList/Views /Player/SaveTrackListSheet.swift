//
//  SaveTrackListSheet.swift
//  TrackList
//
//  Sheet "Сохранить трек-лист"
//
//  Created by Pavel Fomin on 11.07.2025.
//

import Foundation
import SwiftUI

struct SaveTrackListSheet: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    var onSave: (_ name: String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // MARK: - Инпут
                
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
                
                // MARK: - Кнопки
                
                HStack(spacing: 16) {
                    Button {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
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
            .onAppear {
                name = generateDefaultTrackListName()
            }
        }
    }
}
