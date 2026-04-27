//
//  LibraryTrackRowWrapper.swift
//  TrackList
//
//  Обёртка для TrackRowView с реакцией на playerViewModel.
//  Чистый UI-компонент — не содержит навигации.
//  NavigationCoordinator и маршруты здесь НЕ используются.
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import UIKit

struct LibraryTrackRowWrapper: View {
    
    // MARK: - Input
    
    let track: LibraryTrack                       /// Текущий трек строки
    let allTracks: [LibraryTrack]                 /// Контекст всех треков (для переключения)
    
    let trackListViewModel: TrackListViewModel    /// ViewModel треклистов (используется для действий)
    let trackListNamesById: [UUID: [String]]      /// Названия треклистов, в которые входит трек
    
    let metadataProvider: TrackMetadataProviding  /// Провайдер runtime snapshot
    
    let isScrollingFast: Bool                     /// Флаг быстрого скролла (для оптимизации загрузки)
    let isRevealed: Bool                          /// Состояние раскрытия (для свайпов)
    
    let showsSelection: Bool                      /// Включён ли режим выбора
    let isSelected: Bool                          /// Выбран ли текущий трек
    
    let onToggleSelection: () -> Void             /// Обработчик выбора
    
    @ObservedObject var playerViewModel: PlayerViewModel   /// ViewModel плеера
    @EnvironmentObject var sheetManager: SheetManager      /// Менеджер шитов
    
    // MARK: - Player state
    
    /// Является ли трек текущим (играющим)
    private var isCurrent: Bool {
        playerViewModel.isCurrent(track, in: .library)
    }
    
    /// Находится ли трек в состоянии воспроизведения
    private var isPlaying: Bool {
        isCurrent && playerViewModel.isPlaying
    }
    
    /// Названия треклистов, в которых находится трек
    private var trackListNames: [String] {
        trackListNamesById[track.id] ?? []
    }
    
    /// Подсветка строки (например при возврате из sheet)
    private var isHighlighted: Bool {
        sheetManager.highlightedTrackID == track.id
    }
    
    
    // MARK: - Snapshot
    
    /// Runtime snapshot трека (единый источник метаданных)
    private var snapshot: TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: track.id)
    }
    
    /// Обложка трека (строится из snapshot.artworkData)
    private var artwork: UIImage? {
        guard let data = snapshot?.artworkData else { return nil }
        
        return ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: data,
            purpose: .trackList
        )
    }
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isRevealed || isHighlighted,
            artwork: artwork,
            
            // Данные отображения берём из snapshot (если он есть),
            // иначе используем fallback из модели трека
            title: snapshot?.title ?? track.title,
            artist: snapshot?.artist ?? track.artist ?? "",
            duration: snapshot?.duration ?? track.duration,
            
            onRowTap: {
                // Если тап по текущему треку — пауза/воспроизведение
                if isCurrent {
                    playerViewModel.togglePlayPause()
                } else {
                    // Иначе запускаем новый трек в контексте
                    playerViewModel.play(track: track, context: allTracks)
                }
            },
            onArtworkTap: {
                // Открытие экрана деталей трека
                sheetManager.present(.trackDetail(track))
            },
            showsSelection: showsSelection,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            trackListNames: trackListNames
        )
        
        // Загружаем snapshot при появлении строки
        // Больше не используем metadata cache и revision
        .task(id: track.id.uuidString + "|" + (isScrollingFast ? "1" : "0")) {
            metadataProvider.requestSnapshotIfNeeded(for: track.id)
        }
        
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !showsSelection {

                // Добавить в плеер
                Button {
                    Task {
                        try? await AppCommandExecutor.shared.addTrackToPlayer(
                            trackId: track.id
                        )
                    }
                } label: {
                    Label("В плеер", systemImage: "waveform")
                }
                .tint(.blue)

                // Добавить в треклист
                Button {
                    sheetManager.present(
                        .addToTrackList(
                            AddToTrackListSheetData(
                                track: track,
                                sourceTrackListId: nil
                            )
                        )
                    )
                } label: {
                    Label("В треклист", systemImage: "list.star")
                }
                .tint(.green)

                // Переместить трек в другую папку
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .moveToFolder,
                        track: track,
                        context: .library
                    )
                } label: {
                    Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
                }
                .tint(.gray)
            }
        }
    }
}

// MARK: - Helpers

private extension View {
    
    // Условное применение swipeActions
    ///
    /// - Parameters:
    ///   - enabled: включены ли свайпы
    ///   - actions: содержимое свайпов
    @ViewBuilder
    func swipeIf(
        _ enabled: Bool,
        @ViewBuilder actions: (Self) -> some View
    ) -> some View {
        if enabled {
            actions(self)
        } else {
            self
        }
    }
}
