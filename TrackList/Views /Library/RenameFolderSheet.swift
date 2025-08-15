//
//  RenameFolderSheet.swift
//  TrackList
//
//  Показывает текстовое поле для ввода нового имени папки или файла
//
//  Created by Pavel Fomin on 13.08.2025.
//

import Foundation
import SwiftUI
import UIKit

struct RenameFolderSheet: View {
    let originalURL: URL
    let onRename: (String) -> Void   // Новое имя передаётся при подтверждении

    @EnvironmentObject private var sheetManager: SheetManager
    @State private var newName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Новое имя")) {
                    TextField("Введите имя", text: $newName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Переименовать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        sheetManager.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onRename(trimmed)
                        sheetManager.dismiss()
                    }
                }
            }
            .onAppear {
                newName = originalURL.lastPathComponent
            }
        }
    }
}
