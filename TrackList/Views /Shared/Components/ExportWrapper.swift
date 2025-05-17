//
//  ExportWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 06.05.2025.
//

import Foundation
import SwiftUI

struct ExportWrapper: View {
    let onSelect: (URL) -> Void

    var body: some View {
        ExportFolderPicker(onFolderPicked: onSelect)
    }
}
