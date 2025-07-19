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
        VStack(spacing: 16) {
            Text("Сохранить треклист")
                .font(.headline)
                .padding(.top)

            TextField("Название", text: $name)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: {
                    onSave()
                    isPresented = false
                }) {
                    Text("Сохранить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Отмена")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            }
            .padding(.horizontal)

            Spacer(minLength: 12)
        }
        .padding(.bottom)
        .presentationDetents([.height(280)])
    }
}
