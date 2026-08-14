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
    
    // MARK: - Входные данные
    
    @Binding var name: String
    
    let canSubmit: Bool
    let onCreateEmpty: () -> Void
    let onAddTracks: () -> Void
    let onCancel: () -> Void
    
    // MARK: - Фокус
    
    /// Состояние фокуса поля ввода.
    /// Управляется sheet-компонентом, чтобы снимать focus до закрытия или перехода к другому sheet.
    @FocusState private var isNameFocused: Bool
    
    // MARK: - Интерфейс
    
    var body: some View {
        NavigationBarHost(
            title: "New Tracklist",
            rightButtonImage: nil,
            isRightEnabled: .constant(false),
            onClose: {
                finishEditing()
                onCancel()
            }
        ) {
            form
        }
    }

    /// Содержимое формы создания треклиста.
    private var form: some View {
        VStack(spacing: 20) {
            
            Form {
                Section {
                    TextField("Tracklist Name", text: $name)
                        .clearable($name)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.none)
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .onSubmit {
                            finishEditing()
                        }
                }
            }
            
            /// ограничиваем, чтобы Form не занимал весь экран
            
            /// Кнопки действий
            VStack(spacing: 12) {
                
                Button {
                    finishEditing()
                    onAddTracks()
                } label: {
                    Text("Add Tracks")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .disabled(!canSubmit)
                
                Button {
                    finishEditing()
                    onCreateEmpty()
                } label: {
                    Text("Add Tracks Later")
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

    /// Снимает фокус с поля ввода перед закрытием или сменой sheet.
    private func finishEditing() {
        isNameFocused = false
    }
}
