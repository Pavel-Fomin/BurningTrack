//
//  ExportWrapper.swift
//  TrackList
//
//  Обёртка для выбора папки экспорта (используется в .sheet)
//
//  Created by Pavel Fomin on 06.05.2025.
//

import Foundation
import SwiftUI

struct ExportWrapper: View {
    /// Колбэк, вызывается после выбора папки
    let onSelect: (URL) -> Void

    var body: some View {
        // Используем UIKit-компонент через SwiftUI
        ExportFolderPicker(onFolderPicked: onSelect)
    }
}
