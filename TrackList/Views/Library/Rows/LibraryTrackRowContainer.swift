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

struct LibraryTrackRowContainer: View {

    // MARK: - Input

    let state: LibraryTrackRowState               /// Готовое состояние строки без iCloud runtime-состояния
    let allTracks: [LibraryTrack]                 /// Контекст всех треков (для переключения)
    let commandHandler: LibraryTrackCommandHandler /// Обработчик намерений строки
    @ObservedObject var cloudAvailabilityStateStore: CloudTrackAvailabilityRowStateStore /// Точечное runtime-состояние iCloud

    // MARK: - State

    /// Добавляет к готовому состоянию только обновление iCloud текущей строки.
    private var rowState: LibraryTrackRowState {
        state.replacingCloudAvailabilityState(
            cloudAvailabilityStateStore.state
        )
    }

    /// Проверяет доступность пункта меню для локального трека фонотеки.
    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: .library,
            context: .library
        )
    }

    // MARK: - UI

    var body: some View {
        TrackRowView(
            track: rowState.track,
            isCurrent: rowState.isCurrent,
            isPlaying: rowState.isPlaying,
            isHighlighted: rowState.isHighlighted,
            artworkRequest: rowState.artworkRequest,
            // Данные отображения берём из LibraryTrackRowState.
            title: rowState.title,
            artist: rowState.artist,
            duration: rowState.duration,
            onRowTap: {
                commandHandler.handle(
                    .tapRow(
                        track: rowState.track,
                        context: allTracks
                    )
                )
            },
            showsSelection: rowState.showsSelection,
            isSelected: rowState.isSelected,
            onToggleSelection: {
                commandHandler.handle(.toggleSelection)
            },
            selectionPlacement: .trailing,
            showsFileFormat: rowState.showsFileFormat,
            isContentAvailable: rowState.isContentAvailable,
            trackListNames: rowState.trackListNames,
            trailingContent: cloudAvailabilityIndicator
        ) {
            libraryActionMenuContent
        }
        // Запрашиваем snapshot только при смене физического трека, а не скорости прокрутки.
        .task(id: rowState.track.trackId) {
            commandHandler.handle(
                .requestSnapshot(trackId: rowState.track.trackId)
            )
        }
        // Строка сообщает только видимость; файловая проверка выполняется общей очередью экрана.
        .onAppear {
            commandHandler.handle(
                .trackDidAppear(trackId: rowState.track.trackId)
            )
        }
        .onDisappear {
            commandHandler.handle(
                .trackDidDisappear(trackId: rowState.track.trackId)
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !rowState.showsSelection && rowState.isContentAvailable {
                // Добавить в плеер
                if isMenuActionAvailable(.addToPlayer) {
                    Button {
                        commandHandler.handle(
                            .addToPlayer(trackId: rowState.track.trackId)
                        )
                    } label: {
                        Label("Add to Player", systemImage: "waveform")
                    }
                    .tint(.blue)
                }

                // Добавить в треклист
                if isMenuActionAvailable(.addToTrackList) {
                    Button {
                        commandHandler.handle(
                            .addToTrackList(track: rowState.track)
                        )
                    } label: {
                        Label("Add to Tracklist", systemImage: "list.star")
                    }
                    .tint(.green)
                }

                // Переместить трек в другую папку
                if isMenuActionAvailable(.moveToFolder) {
                    Button {
                        commandHandler.handle(
                            .moveToFolder(track: rowState.track)
                        )
                    } label: {
                        Label("Move", systemImage: "arrow.forward.folder")
                    }
                    .tint(.gray)
                }
            }
        }
    }

    /// Меню действий строки фонотеки.
    @ViewBuilder
    private var libraryActionMenuContent: some View {
        LibraryTrackActionMenuContent(
            labels: LibraryPresentationText.trackActionMenuLabels,
            onDetails: {
                commandHandler.handle(
                    .tapArtwork(track: rowState.track)
                )
            },
            onMoveToFolder: {
                commandHandler.handle(
                    .moveToFolder(track: rowState.track)
                )
            },
            onAddToPlayer: {
                commandHandler.handle(
                    .addToPlayer(trackId: rowState.track.trackId)
                )
            },
            onAddToTrackList: {
                commandHandler.handle(
                    .addToTrackList(track: rowState.track)
                )
            },
            onEditTags: {
                commandHandler.handle(
                    .editTags(track: rowState.track)
                )
            },
            onRenameFile: { strategy in
                commandHandler.handle(
                    .rename(
                        trackId: rowState.track.trackId,
                        strategy: strategy
                    )
                )
            }
        )
    }

    /// Готовит единственный индикатор iCloud вместо меню для недоступного локально файла.
    private var cloudAvailabilityIndicator: AnyView? {
        switch rowState.cloudAvailabilityState {
        case .notDownloaded:
            return AnyView(
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Track Not Downloaded from iCloud")
            )

        case .downloading:
            return AnyView(
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Track Is Downloading from iCloud")
            )

        case .downloadFailed:
            return AnyView(
                Button {
                    commandHandler.handle(
                        .retryCloudDownload(trackId: rowState.track.trackId)
                    )
                } label: {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry iCloud Track Download")
            )

        case .local,
             .none:
            return nil
        }
    }
}
