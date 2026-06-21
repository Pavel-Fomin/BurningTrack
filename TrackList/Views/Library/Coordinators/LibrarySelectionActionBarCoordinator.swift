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
            title: pendingAction.title,
            subtitle: "Выбрано: \(selectedCount)",
            primaryTitle: "Применить",
            iconName: pendingAction.iconName,
            isPrimaryEnabled: hasSelection,
            onPrimaryTap: onPrimaryTap
        )
    }
}
