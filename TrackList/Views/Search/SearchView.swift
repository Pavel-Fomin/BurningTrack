//
//  SearchView.swift
//  TrackList
//
//  View раздела поиска.
//  Created by Pavel Fomin on 08.07.2026.
//

import SwiftUI

struct SearchView: View {
    let state: SearchScreenState
    @ObservedObject var playerViewModel: PlayerViewModel
    let onSearchActivityChanged: (Bool) -> Void
    let onAction: (SearchAction) -> Void

    var body: some View {
        content
            .background(
                SearchActivityObserver(
                    onSearchActivityChanged: onSearchActivityChanged
                )
            )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if state.contentState == .results {
            searchList
        } else {
            ZStack {
                searchList
                stateOverlay
            }
        }
    }

    /// В results List остаётся основным scroll-контейнером для нативного схлопывания large title.
    private var searchList: some View {
        List {
            if state.contentState == .results {
                resultRows
            }
        }
        .listStyle(.plain)
        .globalBottomScrollReserve()
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var resultRows: some View {
        if state.trackFilterChips.isEmpty == false {
            FilterChipsView(
                items: state.trackFilterChips,
                selectedItem: selectedTrackFilterChip,
                title: { SearchPresentationText.filterTitle(for: $0.field) },
                detail: { "\($0.count)" },
                onSelect: { chip in
                    onAction(.selectTrackFilter(chip.field))
                }
            )
            // Чипы остаются отдельной строкой списка и не вмешиваются в TrackRowView.
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }

        if state.folders.isEmpty == false {
            Section(header: sectionHeader(String(localized: "Folders"))) {
                ForEach(state.folders) { folder in
                    SearchFolderRowView(
                        result: folder,
                        onAction: onAction
                    )
                    // Сбрасываем стандартный фон ячейки List, чтобы строка совпадала с TrackRowView.
                    .listRowBackground(Color.clear)
                }
            }
        }

        if state.trackLists.isEmpty == false {
            Section(header: sectionHeader(String(localized: "Tracklists"))) {
                ForEach(state.trackLists) { row in
                    SearchTrackListRowView(
                        row: row,
                        onAction: onAction
                    )
                    // Сбрасываем стандартный фон ячейки List, чтобы строка совпадала с TrackRowView.
                    .listRowBackground(Color.clear)
                }
            }
        }

        if state.tracks.isEmpty == false {
            Section(header: sectionHeader(String(localized: "Tracks"))) {
                ForEach(state.tracks) { row in
                    SearchTrackRowView(
                        row: row,
                        playerViewModel: playerViewModel,
                        onAction: onAction
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch state.contentState {
        case .emptyQuery:
            SearchMessageView(
                title: String(localized: "Start Searching"),
                description: nil
            )

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .results:
            EmptyView()

        case .noResults:
            SearchMessageView(
                title: String(localized: "No Results"),
                description: String(localized: "Try a Different Search")
            )
        }
    }

    /// Заголовок секции соответствует типу найденной сущности.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    /// Находит выбранный чип по готовому состоянию, не вычисляя фильтрацию во View.
    private var selectedTrackFilterChip: TrackSearchFilterChip? {
        state.trackFilterChips.first { chip in
            chip.field == state.selectedTrackFilterField
        }
    }
}

// MARK: - Empty State

private struct SearchMessageView: View {
    let title: String
    let description: String?

    var body: some View {
        VStack {
            Spacer()

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Activity

private struct SearchActivityObserver: View {
    @Environment(\.isSearching) private var isSearching

    let onSearchActivityChanged: (Bool) -> Void

    var body: some View {
        Color.clear
            // Передаём системную активность поиска наверх без управления самой search presentation.
            .onAppear {
                onSearchActivityChanged(isSearching)
            }
            .onChange(of: isSearching) { _, isSearching in
                onSearchActivityChanged(isSearching)
            }
    }
}

// MARK: - Result Row

private struct SearchFolderRowView: View {
    let result: SearchFolderResult
    let onAction: (SearchAction) -> Void

    /// Папка поиска отображается тем же компонентом, что и папка фонотеки.
    var body: some View {
        LibraryFolderRowView(
            name: result.displayTitle,
            showsDisclosureIndicator: true
        ) {
            onAction(.openFolder(result))
        }
    }
}

private struct SearchTrackListRowView: View {
    let row: SearchTrackListRowState
    let onAction: (SearchAction) -> Void

    /// Треклист поиска отображается тем же компонентом, что и список треклистов.
    var body: some View {
        TrackListsRowView(
            title: row.result.trackList.name,
            createdAtText: TrackListPresentationText.createdAt(
                row.result.trackList.createdAt
            ),
            tracksCountText: TrackListPresentationText.trackCount(
                row.result.trackList.tracks.count
            )
        ) {
            onAction(.openTrackList(row.result))
        }
    }
}

private struct SearchTrackRowView: View {
    let row: SearchTrackRowState
    @ObservedObject var playerViewModel: PlayerViewModel
    let onAction: (SearchAction) -> Void

    /// Найденный трек считается текущим по стабильному trackId, без сравнения названия или артиста.
    private var isCurrent: Bool {
        playerViewModel.currentTrackDisplayable?.trackId == row.result.trackId
    }

    /// Трек поиска остаётся обычной строкой TrackRowView.
    var body: some View {
        TrackRowView(
            track: row.result,
            isCurrent: isCurrent,
            isPlaying: isCurrent && playerViewModel.isPlaying,
            isHighlighted: false,
            artworkRequest: row.artworkRequest,
            title: row.title,
            artist: row.artist,
            duration: row.duration,
            onRowTap: {
                onAction(.playTrack(row.result))
            },
            showsSelection: false,
            isSelected: false,
            onToggleSelection: nil,
            selectionPlacement: .trailing,
            showsFileFormat: row.showsFileFormat,
            trackListNames: row.trackListNames,
            useNativeSwipeActions: false
        ) {
            searchActionMenuContent
        }
        // Snapshot запрашивается через action layer, как в строках фонотеки.
        .task(id: row.result.trackId) {
            onAction(.requestTrackSnapshot(row.result.trackId))
        }
    }

    /// Меню найденного трека повторяет применимые действия строки фонотеки.
    @ViewBuilder
    private var searchActionMenuContent: some View {
        LibraryTrackActionMenuContent(
            labels: SearchPresentationText.trackActionLabels,
            onDetails: {
                onAction(.showDetails(row.result))
            },
            onMoveToFolder: {
                onAction(.moveToFolder(row.result))
            },
            onAddToPlayer: {
                onAction(.addToPlayer(row.result.trackId))
            },
            onAddToTrackList: {
                onAction(.addToTrackList(row.result))
            },
            onEditTags: {
                onAction(.editTags(row.result))
            },
            onRenameFile: { strategy in
                onAction(.renameFile(row.result, strategy))
            }
        )
    }
}
