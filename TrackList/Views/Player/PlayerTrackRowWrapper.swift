//
//  PlayerTrackRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import UIKit

struct PlayerTrackRowWrapper: View {
    
    // MARK: - Input
    
    let track: any TrackDisplayable                      /// Трек строки
    let isCurrent: Bool                                  /// Является ли строка текущим треком
    let isPlaying: Bool                                  /// Воспроизводится ли текущий трек
    let onTap: () -> Void                                /// Обработчик тапа по строке
    
    @ObservedObject var playerViewModel: PlayerViewModel /// ViewModel плеера
    @ObservedObject private var settingsManager = AppSettingsManager.shared /// Менеджер настроек отображения
    @EnvironmentObject var sheetManager: SheetManager    /// Менеджер шитов
    
    // MARK: - Snapshot
    
    /// Runtime snapshot трека
    private var snapshot: TrackRuntimeSnapshot? {
        playerViewModel.snapshot(for: track.trackId)
    }
    
    /// Обложка трека
    private var artwork: UIImage? {
        guard AppSettingsManager.shared.settings.visible.metadata.isTagReadingEnabled else { return nil }
        guard let data = snapshot?.artworkData else { return nil }

        return ArtworkProvider.shared.image(
            trackId: track.trackId,
            artworkData: data,
            purpose: .trackList
        )
    }

    /// Актуальное имя файла из runtime snapshot с fallback на модель строки.
    private var displayFileName: String {
        snapshot?.fileName ?? track.fileName
    }
    
    // MARK: - UI
    
    var body: some View {
        let shouldShowTags = settingsManager.settings.visible.metadata.isTagReadingEnabled
        let shouldShowFileFormat = settingsManager.settings.visible.library.isFileFormatVisible

        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: sheetManager.highlightedRowID == track.id,
            artwork: artwork,
            title: shouldShowTags ? (snapshot?.title ?? displayFileName) : displayFileName,
            artist: shouldShowTags ? (snapshot?.artist ?? "") : "",
            duration: snapshot?.duration ?? track.duration,
            onRowTap: onTap,
            onArtworkTap: {
                sheetManager.present(.trackDetail(track))
            },
            showsFileFormat: shouldShowFileFormat
        )
        .trackFileRenameMenu(
            trackId: track.trackId,
            rowId: track.id,
            currentFileName: displayFileName,
            artist: snapshot?.artist,
            title: snapshot?.title,
            playerManager: playerViewModel.playerManager
        )
        .task(id: track.trackId) {
            playerViewModel.requestSnapshotIfNeeded(for: track.trackId)
        }

        // MARK: - Свайпы плеера

        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

            /// Удалить
            Button(role: .destructive) {
                Task {
                    do {
                        try await AppCommandExecutor.shared.removeTrackFromPlayer(
                            queueItemId: track.id
                        )
                    } catch let appError as AppError {
                        ToastManager.shared.handle(appError)
                    } catch {
                        ToastManager.shared.handle(
                            .operationFailed(
                                message: "Не удалось удалить трек из плеера"
                            )
                        )
                    }
                }
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            /// Показать в фонотеке
            Button {
                SheetActionCoordinator.shared.handle(
                    action: .showInLibrary,
                    track: track,
                    context: .player
                )
            } label: {
                Label("Показать", systemImage: "scope")
            }
            .tint(.gray)

            /// Переместить
            Button {
                SheetActionCoordinator.shared.handle(
                    action: .moveToFolder,
                    track: track,
                    context: .player
                )
            } label: {
                Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
            }
            .tint(.blue)
        }
    }
}
