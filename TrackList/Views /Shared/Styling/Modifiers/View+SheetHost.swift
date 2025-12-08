//
//  View+SheetHost.swift
//  TrackList
//
//  Унифицированный контейнер для всех sheet’ов приложения.
//  Использует SheetManager и единый стиль через .appSheet().
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI

struct SheetHostModifier: ViewModifier {

    @ObservedObject var sheetManager = SheetManager.shared
    let playerManager: PlayerManager

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheetManager.activeSheet, onDismiss: {
                sheetManager.handleDismiss()
            }) { sheet in
                switch sheet {

                // MARK: - Track actions (маленький sheet)
                    
                case .trackActions(let data):
                    TrackActionSheet(
                        track: data.track,
                        context: data.context,
                        actions: data.actions,
                        onAction: { action in
                            switch action {
                            case .moveToFolder:
                                sheetManager.present(
                                    .moveToFolder(
                                        MoveToFolderSheetData(track: data.track)
                                    )
                                )

                            case .showInLibrary:
                                NavigationCoordinator.shared.showTrackInLibrary(trackId: data.track.id)
                                sheetManager.closeActive()

                            case .showInfo:
                                sheetManager.present(.trackDetail(data.track))
                            }
                        }
                    )
                    .appSheet(detents: [
                        .height(CGFloat(data.actions.count * 56 + 40))
                    ])

                // MARK: - Move track to folder (большой sheet)
                    
                case .moveToFolder(let data):
                    NavigationStack {
                        MoveToFolderSheet(
                            trackId: data.track.id,
                            onComplete: { sheetManager.closeActive() },
                            playerManager: playerManager
                        )
                    }
                    .appSheet(detents: [.fraction(0.6), .medium])

                // MARK: - Track detail
                case .trackDetail(let track):
                    TrackDetailSheet(track: track)
                        .appSheet(detents: [.large])

                // MARK: - Add to tracklist
                    
                case .addToTrackList(let track):
                    NavigationStack {
                        AddToTrackListSheet(track: track) {
                            sheetManager.closeActive()
                        }
                    }
                    .appSheet(detents: [.fraction(0.6), .medium])
                }
            }
    }
}

extension View {
    func sheetHost(playerManager: PlayerManager) -> some View {
        modifier(SheetHostModifier(playerManager: playerManager))
    }
}
