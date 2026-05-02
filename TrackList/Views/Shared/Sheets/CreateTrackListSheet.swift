//
//  CreateTrackListSheet.swift
//  TrackList
//
//  UI шита "новый треклист"
//
//  Created by PavelFomin on 01.05.2026.
//

import Foundation
import SwiftUI

struct CreateTrackListSheet: View {
    
    // MARK: - Input
    
    @Binding var name: String   /// Название нового треклиста.
    
    let canSubmit: Bool  /// Можно ли выполнить действие с текущим названием.
    let onAddTracks: () -> Void  // Действие "Добавить треки".
    let onAddLater: () -> Void  /// Действие "Добавить треки позже".
    
    // MARK: - Focus
    
    @FocusState private var isNameFocused: Bool /// Фокус поля имени для автоматического открытия клавиатуры.
    
    // MARK: - UI
    
    var body: some View {
        VStack(spacing: 20) {
            
            /// Поле ввода — оставляем как в SaveTrackListSheet
            Form {
                Section {
                    TextField("Название треклиста", text: $name)
                        .clearable($name)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
            }
            
            /// ограничиваем, чтобы Form не занимал весь экран
            
            /// Кнопки действий
            VStack(spacing: 12) {
                
                Button {
                    onAddTracks()
                } label: {
                    Text("Добавить треки")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .disabled(!canSubmit)
                
                Button {
                    onAddLater()
                } label: {
                    Text("Добавить треки позже")
                        .frame(maxWidth: .infinity)
                }
                .secondaryButtonStyle()
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
        
        /// автофокус как в остальных шитах
        .task {
            isNameFocused = true
        }
    }
}
