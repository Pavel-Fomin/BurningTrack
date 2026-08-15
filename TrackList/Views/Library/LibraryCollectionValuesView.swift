//
//  LibraryCollectionValuesView.swift
//  TrackList
//
//  Экран значений раздела музыкальной коллекции.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import SwiftUI

struct LibraryCollectionValuesView: View {
    // MARK: - ViewModel

    /// ViewModel владеет загрузкой значений из provider и не знает о NavigationStack.
    @ObservedObject private var viewModel: LibraryCollectionValuesViewModel
    /// Контроллер runtime snapshot-ов сохраняет точечную загрузку обложки вне PlayerViewModel.
    @ObservedObject private var runtimeController: LibraryTrackRuntimeController
    /// Единый снимок сохраняет реактивность album-строк без наблюдения PlayerViewModel.
    @State private var playbackState: PlaybackStateSnapshot

    // MARK: - Входные данные

    /// Передаёт выбранное значение наружу, чтобы навигацией управлял контейнер фонотеки.
    let onValueSelected: (LibraryCollectionValue) -> Void
    /// Предоставляет playback-состояние только для подсветки album-строки.
    let playbackStateProvider: any PlaybackStateProviding

    // MARK: - Инициализация

    init(
        viewModel: LibraryCollectionValuesViewModel,
        runtimeController: LibraryTrackRuntimeController,
        playbackStateProvider: any PlaybackStateProviding,
        onValueSelected: @escaping (LibraryCollectionValue) -> Void
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._runtimeController = ObservedObject(wrappedValue: runtimeController)
        self._playbackState = State(
            initialValue: playbackStateProvider.playbackState
        )
        self.playbackStateProvider = playbackStateProvider
        self.onValueSelected = onValueSelected
    }

    // MARK: - Интерфейс

    var body: some View {
        content
            .navigationTitle(
                LibraryPresentationText.collectionCategoryTitle(
                    for: viewModel.state.category
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    valueSortMenu
                }
            }
            .task {
                viewModel.send(.screenAppeared)
            }
            .onReceive(playbackStateProvider.playbackStatePublisher) { playbackState in
                self.playbackState = playbackState
            }
    }

    /// Меню сортировки значений повторяет паттерн сортировки поиска; вложенные группы нужны только альбомам.
    private var valueSortMenu: some View {
        let category = viewModel.state.category

        return Menu {
            ForEach(category.availableValueSortMenuGroups) { group in
                sortMenuGroup(group, category: category)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Collection Value Sorting")
    }

    /// Строит группу меню из тех режимов, которые разрешены для выбранного раздела.
    @ViewBuilder
    private func sortMenuGroup(
        _ group: LibraryCollectionValueSortMode.MenuGroup,
        category: LibraryCollectionCategory
    ) -> some View {
        let modes = category.availableValueSortModes.filter { $0.menuGroup == group }

        if category != .albums {
            ForEach(modes) { mode in
                valueSortButton(mode)
            }
        } else {
            Menu {
                ForEach(modes) { mode in
                    valueSortButton(mode)
                }
            } label: {
                Text(LibraryPresentationText.collectionValueSortMenuGroupTitle(for: group))
            }
        }
    }

    /// Передаёт выбранный режим во ViewModel и показывает checkmark у активного пункта.
    private func valueSortButton(
        _ mode: LibraryCollectionValueSortMode
    ) -> some View {
        Button {
            viewModel.send(.sortModeSelected(mode))
        } label: {
            Label {
                Text(LibraryPresentationText.collectionValueSortModeTitle(for: mode))
            } icon: {
                if viewModel.state.sortMode == mode {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isLoading {
            loadingView
        } else if viewModel.state.isEmpty {
            emptyView
        } else {
            valuesList(viewModel.state.values)
        }
    }

    /// Показывает состояние загрузки значений из SQLite metadata.
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text("Loading Values")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Показывает пустое состояние, если в сохранённых metadata нет значений раздела.
    private var emptyView: some View {
        Text("No Values")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Показывает плоский список значений выбранного раздела коллекции.
    private func valuesList(
        _ values: [LibraryCollectionValue]
    ) -> some View {
        List(values) { value in
            collectionRow(value)
        }
        .listStyle(.plain)
        .globalBottomScrollReserve()
        .scrollContentBackground(.hidden)
    }

    /// Выбирает специализированную строку только для альбомов.
    @ViewBuilder
    private func collectionRow(_ value: LibraryCollectionValue) -> some View {
        if viewModel.state.category == .albums {
            albumValueRow(value)
        } else {
            valueRow(value)
        }
    }

    /// Строит строку значения с переходом к списку треков.
    private func valueRow(_ value: LibraryCollectionValue) -> some View {
        Button {
            onValueSelected(value)
        } label: {
            HStack(spacing: 12) {
                Text(value.title)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Строит album-строку без счётчика треков и без запуска воспроизведения.
    private func albumValueRow(_ value: LibraryCollectionValue) -> some View {
        let isCurrent = isCurrentAlbum(value)

        return Button {
            onValueSelected(value)
        } label: {
            LibraryAlbumValueRowView(
                value: value,
                artworkRequest: albumArtworkRequest(for: value),
                isCurrent: isCurrent,
                isPlaying: isCurrent && playbackState.isPlaying
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
        .task(id: value.representativeTrackId) {
            requestAlbumArtworkIfNeeded(for: value)
        }
    }

    /// Собирает лёгкий запрос из runtime snapshot representative track, если он уже загружен.
    private func albumArtworkRequest(for value: LibraryCollectionValue) -> ArtworkRequest? {
        guard let representativeTrackId = value.representativeTrackId,
              let snapshot = runtimeController.snapshot(for: representativeTrackId),
              snapshot.artworkData != nil else {
            return nil
        }

        return ArtworkRequest(
            trackId: representativeTrackId,
            snapshot: snapshot,
            purpose: .trackList
        )
    }

    /// Проверяет, находится ли текущий трек плеера внутри выбранного альбома.
    private func isCurrentAlbum(_ value: LibraryCollectionValue) -> Bool {
        if let currentDisplayableId = playbackState.currentDisplayableId,
           value.trackIds.contains(currentDisplayableId) {
            return true
        }

        if let currentTrackId = playbackState.currentTrackId,
           value.trackIds.contains(currentTrackId) {
            return true
        }

        return false
    }

    /// Точечно запрашивает runtime snapshot только для representative track видимой album-строки.
    @MainActor
    private func requestAlbumArtworkIfNeeded(for value: LibraryCollectionValue) {
        guard let representativeTrackId = value.representativeTrackId else { return }

        runtimeController.requestSnapshotIfNeeded(for: representativeTrackId)
    }
}
