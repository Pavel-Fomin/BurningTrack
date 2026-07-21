//
//  LibrarySelectionActionBarCoordinator.swift
//  TrackList
//
//  Собирает конфигурацию нижней панели выбора для экрана треков фонотеки.
//
//  Created by Pavel Fomin on 22.06.2026.
//

/// Координирует отображение нижней панели подтверждения bulk-действия.
@MainActor
struct LibrarySelectionActionBarCoordinator {

    /// Собирает конфигурацию панели подтверждения для выбранного bulk-действия.
    func makeConfig(
        pendingAction: BulkTrackAction?,
        selectedCount: Int,
        hasSelection: Bool,
        onPrimaryTap: @escaping () -> Void
    ) -> SelectionActionBarConfig? {
        guard let pendingAction else { return nil }

        return SelectionActionBarConfig(
            title: LibraryPresentationText.bulkActionTitle(for: pendingAction),
            subtitle: LibraryPresentationText.selectedTrackCountText(for: selectedCount),
            primaryTitle: "Apply",
            iconName: pendingAction.iconName,
            isPrimaryEnabled: hasSelection,
            onPrimaryTap: onPrimaryTap
        )
    }
}
