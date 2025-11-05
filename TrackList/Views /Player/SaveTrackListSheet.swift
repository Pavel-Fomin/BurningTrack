//
//  SaveTrackListSheet.swift
//  TrackList
//
//  Created by Pavel Fomin on 11.07.2025.
//

import Foundation
import SwiftUI

struct SaveTrackListSheet: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    var onSave: () -> Void
    
    var body: some View {
            NavigationStack {
                ZStack(alignment: .bottom) {
                    
// MARK: - Инпут
                    List {
                        Section {
                            TextField("Название", text: $name)
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
                            onSave()
                            isPresented = false
                        } label: {
                            Text("Сохранить")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            isPresented = false
                        } label: {
                            Text("Отмена")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .presentationDetents([.height(208)])
            }
        }
    }
