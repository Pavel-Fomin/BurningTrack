//
//  TrackActionSheet.swift
//  TrackList
//
//  Действия над треком: Показать в фонотеке, Переместить, О треке
//
//  Created by Pavel Fomin on 16.09.2025.
//

import Foundation
import SwiftUI

struct TrackActionSheet: View {
    let track: any TrackDisplayable
    let context: TrackContext
    let actions: [TrackAction]

    let onAction: (TrackAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(actions, id: \.self) { action in
                Button {
                    if action == .showInfo {
                        SheetManager.shared.closeAllSheets()
                        TrackDetailManager.shared.open(track: track)
                    } else if action == .showInLibrary {
                        SheetManager.shared.closeAllSheets()
                        
                        // Переход к папке с треком
                        print("🧭 [TrackActionSheet] showInLibrary вызван для:", track.url.lastPathComponent)
                        NavigationCoordinator.shared.showInLibrary(for: track.url)
                        
                    } else {
                        onAction(action)
                    }
                } label: {
                    HStack(spacing: 12) {
                        icon(for: action)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 28)
                        Text(title(for: action))
                            .font(.system(size: 17))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.vertical, 0)
        .onDisappear {
            SheetManager.shared.highlightedTrackID = nil
        }
    }
    

    private func title(for action: TrackAction) -> String {
        switch action {
        case .showInLibrary: return "Показать в фонотеке"
        case .moveToFolder:  return "Переместить"
        case .showInfo:      return "О треке"
        }
    }

    private func icon(for action: TrackAction) -> Image {
        switch action {
        case .showInLibrary: return Image(systemName: "folder")
        case .moveToFolder:  return Image(systemName: "arrow.right.doc.on.clipboard")
        case .showInfo:      return Image(systemName: "info.circle")
        }
    }
}
