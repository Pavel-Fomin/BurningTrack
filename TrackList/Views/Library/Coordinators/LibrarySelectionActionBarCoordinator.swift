//
//  LibrarySelectionActionBarCoordinator.swift
//  TrackList
//
//  Собирает конфигурацию нижней панели выбора для экрана треков фонотеки.
//
//  Created by Pavel Fomin on 22.06.2026.
//

/// Координирует отображение нижней панели выбора и подтверждения bulk-действия.
@MainActor
struct LibrarySelectionActionBarCoordinator {

    /// Собирает данные панели для всего активного режима выбора.
    /// pendingAction меняет только содержимое панели и никогда не определяет её существование.
    /// Выбор принадлежит Library Tracks, а действие подтверждения не входит в state
    /// и возвращается host-экраном через LibraryTracksAction.
    func makeState(
        isSelecting: Bool,
        pendingAction: BulkTrackAction?,
        selectedCount: Int,
        hasSelection: Bool
    ) -> LibrarySelectionActionBarState? {
        guard isSelecting else { return nil }

        return LibrarySelectionActionBarState(
            selectedCount: selectedCount,
            isActionEnabled: pendingAction != nil && hasSelection,
            pendingAction: pendingAction
        )
    }

    /// Преобразует screen state в визуальную конфигурацию общего host без callback-а.
    /// В обычном режиме панель показывает число выбранных треков без кнопки подтверждения.
    func makeConfig(
        from state: LibrarySelectionActionBarState
    ) -> SelectionActionBarConfig {
        SelectionActionBarConfig(
            title: state.pendingAction.map(LibraryPresentationText.bulkActionTitle)
                ?? String(localized: "Selected"),
            subtitle: LibraryPresentationText.selectedTrackCountText(for: state.selectedCount),
            primaryTitle: state.pendingAction == nil ? nil : "Apply",
            iconName: state.pendingAction?.iconName,
            isPrimaryEnabled: state.isActionEnabled
        )
    }
}
