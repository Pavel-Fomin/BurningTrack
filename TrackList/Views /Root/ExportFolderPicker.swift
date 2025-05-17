//
//  ExportFolderPicker.swift
//  TrackList
//
//  Компонент выбора папки экспорта
//
//  Created by Pavel Fomin on 06.05.2025.
//

import Foundation
import SwiftUI
import UIKit

struct ExportFolderPicker: UIViewControllerRepresentable {
    var onFolderPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // ничего не делаем
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFolderPicked: onFolderPicked)
    }

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
