//
//  MoveFolderSheet.swift
//  TrackList
//
//  Показывает список доступных папок для перемещения выбранной папки или файла
//
//  Created by Pavel Fomin on 13.08.2025.
//

import Foundation
import SwiftUI
import UIKit

struct MoveFolderSheet: View {
    let sourceURL: URL
    let availableFolders: [URL]      // Папки, куда можно переместить
    let onMove: (URL) -> Void        // Новый URL вызывается при выборе

    @EnvironmentObject private var sheetManager: SheetManager

    var body: some View {
        NavigationView {
            List {
                ForEach(availableFolders, id: \.self) { folderURL in
                    Button {
                        onMove(folderURL)
                        sheetManager.dismiss()
                    } label: {
                        Text(folderURL.lastPathComponent)
                    }
                }
            }
            .navigationTitle("Выберите папку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        sheetManager.dismiss()
                    }
                }
            }
        }
    }
}
