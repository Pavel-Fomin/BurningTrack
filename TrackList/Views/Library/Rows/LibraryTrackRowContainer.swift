//
//  LibraryTrackRowContainer.swift
//  TrackList
//
//  Контейнер строки фонотеки.
//  Адаптер для TrackRowView в контексте фонотеки.
//  Собирает состояние строки, обработчики и действия вокруг чистого TrackRowView.
//  Не содержит самостоятельной бизнес-логики строки.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import SwiftUI
import UIKit

struct LibraryTrackRowContainer: View {

    // MARK: - Input

    let track: LibraryTrack                       /// Текущий трек строки
    let allTracks: [LibraryTrack]                 /// Контекст всех треков (для переключения)
    let trackListNamesById: [UUID: [String]]      /// Названия треклистов, в которые входит трек
    let metadataProvider: TrackMetadataProviding  /// Провайдер runtime snapshot
    let isScrollingFast: Bool                     /// Флаг быстрого скролла (для оптимизации загрузки)
    let isRevealed: Bool                          /// Состояние раскрытия (для свайпов)
    let showsSelection: Bool                      /// Включён ли режим выбора
    let isSelected: Bool                          /// Выбран ли текущий трек
    let onToggleSelection: () -> Void             /// Обработчик выбора
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void /// Обработчик переименования трека
    @ObservedObject var playerViewModel: PlayerViewModel   /// ViewModel плеера
    @ObservedObject private var settingsManager = AppSettingsManager.shared /// Менеджер настроек отображения
    @EnvironmentObject var sheetManager: SheetManager      /// Менеджер шитов

    // MARK: - Handlers

    /// Обработчик воспроизведения строки.
    private var playbackHandler: LibraryTrackPlaybackHandler {
        LibraryTrackPlaybackHandler(
            playerViewModel: playerViewModel
        )
    }

    /// Обработчик подготовки данных отображения строки.
    private var presentationHandler: LibraryTrackPresentationHandler {
        LibraryTrackPresentationHandler(
            metadataProvider: metadataProvider
        )
    }

    /// Обработчик команд строки.
    private var commandHandler: LibraryTrackCommandHandler {
        LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: playbackHandler,
            presentationHandler: presentationHandler,
            onToggleSelection: onToggleSelection,
            onRenameTrack: onRenameTrack
        )
    }

    // MARK: - State

    /// Runtime snapshot трека (единый источник метаданных).
    private var snapshot: TrackRuntimeSnapshot? {
        presentationHandler.snapshot(for: track.trackId)
    }

    /// Названия треклистов, в которых находится трек.
    private var trackListNames: [String] {
        trackListNamesById[track.trackId] ?? []
    }

    /// Подсветка строки при возврате из sheet.
    private var isSheetHighlighted: Bool {
        sheetManager.highlightedRowID == track.id
    }

    /// Готовое состояние строки для TrackRowView.
    private var rowState: LibraryTrackRowState {
        let shouldShowTags = settingsManager.settings.visible.metadata.isTagReadingEnabled
        let shouldShowTrackListMembership = settingsManager.settings.visible.library.isTrackListMembershipVisible
        let shouldShowFileFormat = settingsManager.settings.visible.library.isFileFormatVisible
        return presentationHandler.makeState(
            track: track,
            snapshot: snapshot,
            isCurrent: playbackHandler.isCurrent(track),
            isPlaying: playbackHandler.isPlaying(track),
            isHighlighted: isRevealed || isSheetHighlighted,
            trackListNames: trackListNames,
            showsSelection: showsSelection,
            isSelected: isSelected,
            shouldShowTags: shouldShowTags,
            shouldShowTrackListMembership: shouldShowTrackListMembership,
            shouldShowFileFormat: shouldShowFileFormat
        )
    }

    // MARK: - UI

    var body: some View {
        TrackRowView(
            track: rowState.track,
            isCurrent: rowState.isCurrent,
            isPlaying: rowState.isPlaying,
            isHighlighted: rowState.isHighlighted,
            artwork: rowState.artwork,
            // Данные отображения берём из LibraryTrackRowState.
            title: rowState.title,
            artist: rowState.artist,
            duration: rowState.duration,
            onRowTap: {
                commandHandler.handle(
                    .tapRow(
                        track: track,
                        context: allTracks
                    )
                )
            },
            onArtworkTap: {
                commandHandler.handle(
                    .tapArtwork(track: track)
                )
            },
            showsSelection: rowState.showsSelection,
            isSelected: rowState.isSelected,
            onToggleSelection: {
                commandHandler.handle(.toggleSelection)
            },
            selectionPlacement: .trailing,
            showsFileFormat: rowState.showsFileFormat,
            trackListNames: rowState.trackListNames
        )
        .trackFileRenameMenu(
            artist: snapshot?.artist,
            title: snapshot?.title,
            isEnabled: !showsSelection,
            onRename: { strategy in
                commandHandler.handle(
                    .rename(
                        trackId: track.trackId,
                        strategy: strategy
                    )
                )
            }
        )
        // Загружаем snapshot при появлении строки.
        // Быстрый скролл остаётся частью id, чтобы сохранить прежнее поведение обновления task.
        .task(id: track.trackId.uuidString + "|" + (isScrollingFast ? "1" : "0")) {
            commandHandler.handle(
                .requestSnapshot(trackId: track.trackId)
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !showsSelection {
                // Добавить в плеер
                Button {
                    commandHandler.handle(
                        .addToPlayer(trackId: track.trackId)
                    )
                } label: {
                    Label("В плеер", systemImage: "waveform")
                }
                .tint(.blue)
                // Добавить в треклист
                Button {
                    commandHandler.handle(
                        .addToTrackList(track: track)
                    )
                } label: {
                    Label("В треклист", systemImage: "list.star")
                }
                .tint(.green)
                // Переместить трек в другую папку
                Button {
                    commandHandler.handle(
                        .moveToFolder(track: track)
                    )
                } label: {
                    Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
                }
                .tint(.gray)
            }
        }
    }
}
