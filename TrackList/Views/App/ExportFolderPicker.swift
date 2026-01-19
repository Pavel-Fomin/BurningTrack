//
//  ExportFolderPicker.swift
//  TrackList
//
//  Компонент выбора папки для экспорта треков (использует UIDocumentPicker)
//
//  Created by Pavel Fomin on 06.05.2025.
//

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ExportFolderPicker: UIViewControllerRepresentable {
    /// Колбэк, вызывается при выборе папки
    var onFolderPicked: (URL) -> Void

    // MARK: - Создание контроллера
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    // MARK: - Обновление контроллера (не используется)
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // ничего не делаем
    }

    // MARK: - Координатор для обработки выбора
    func makeCoordinator() -> Coordinator {
        Coordinator(onFolderPicked: onFolderPicked)
    }

    // MARK: - Coordinator (UIDocumentPickerDelegate)
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFolderPicked: (URL) -> Void

        init(onFolderPicked: @escaping (URL) -> Void) {
            self.onFolderPicked = onFolderPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let folderURL = urls.first {
                onFolderPicked(folderURL)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("❌ Выбор папки отменён")
        }
    }
}
