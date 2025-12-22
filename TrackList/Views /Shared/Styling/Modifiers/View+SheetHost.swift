//
//  View+SheetHost.swift
//  TrackList
//
//  Унифицированный контейнер для всех sheet’ов приложения.
//  Отвечает ТОЛЬКО за отображение sheet’ов по AppSheet.
//  Не содержит логики, навигации и обработки действий.
//
//  Command-based UI Architecture:
//  - SheetHost — тупой UI-контейнер
//  - Sheet’ы сами инициируют команды или UI-действия
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI

struct SheetHostModifier: ViewModifier {

    @ObservedObject private var sheetManager = SheetManager.shared

    /// PlayerManager пока пробрасывается дальше без использования логики.
    /// Будет убран на следующих этапах.
    let playerManager: PlayerManager

    func body(content: Content) -> some View {
        content
            .sheet(
                item: $sheetManager.activeSheet,
                onDismiss: {
                    sheetManager.handleDismiss()
                }
            ) { sheet in switch sheet {
                    
// MARK: - Действия над треком
                    
               /// Сохранение треклиста
               case .saveTrackList:
                NavigationStack {
                    SaveTrackListSheet()
                }
                .appSheet(detents: [.height(208)])
                
                 /// Переименование треклиста
                case .renameTrackList(let data):
                    NavigationStack {
                        RenameTrackListSheet(
                            trackListId: data.trackListId,
                            currentName: data.currentName
                        )
                    }
                    .appSheet(detents: [.height(208)])
                    
                /// Действия над треком
                case .trackActions(let data):
                    TrackActionSheet(
                        track: data.track,
                        context: data.context,
                        actions: data.actions
                    )
                    .appSheet( detents: [.height(CGFloat(data.actions.count * 56 + 40))]
                    )
                    
                /// Перемещение трека
                case .moveToFolder(let data):
                    NavigationStack {
                        MoveToFolderSheet(
                            trackId: data.track.id,
                            playerManager: playerManager
                        )
                    }
                    .appSheet(detents: [.fraction(0.6), .medium])
                    
                /// О треке
                case .trackDetail(let track):
                    TrackDetailSheet(track: track)
                        .appSheet(detents: [.large])
                    
                /// Добавить в треклист
                case .addToTrackList(let data):
                NavigationStack {
                    AddToTrackListSheet(track: data.track)
                }
                .appSheet(detents: [.fraction(0.6), .medium])
                }
            }
    }
}

// MARK: - Публичный модификатор для подключения SheetHost

extension View {

    /// Подключает централизованный SheetHost к экрану.
    /// Используется один раз в корне приложения.
    func sheetHost(playerManager: PlayerManager) -> some View {
        modifier(SheetHostModifier(playerManager: playerManager))
    }
}
