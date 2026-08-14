//
// "LibraryCollectionTracksContainer.swift"
// TrackList
// Создаёт screen-local graph списка общего раздела и значения музыкальной коллекции.
// Created by Pavel Fomin on 13.08.2026.
//

import SwiftUI

/// Создаёт collection graph через StateObject ровно один раз для стабильной identity source.
struct LibraryCollectionTracksContainer: View {
    let source: LibraryTrackListSource
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?
    let onAllTracksAction: ((LibraryAllTracksAction) -> Void)?
    let onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)?

    /// Store удерживает graph выбранного источника и не пересобирается при обновлении родительского View.
    @StateObject private var screenStore: LibraryCollectionTracksScreenStore

    init(
        factory: LibraryTracksScreenFactory,
        source: LibraryTrackListSource,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>,
        onAllTracksAction: ((LibraryAllTracksAction) -> Void)?,
        onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)?
    ) {
        self.source = source
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        self.onAllTracksAction = onAllTracksAction
        self.onCollectionTracksAction = onCollectionTracksAction
        self._screenStore = StateObject(
            wrappedValue: factory.makeCollectionScreenStore(source: source)
        )
    }

    var body: some View {
        LibraryCollectionTracksView(
            source: source,
            screenStore: screenStore,
            selectionActionBarConfig: $selectionActionBarConfig,
            selectionActionSender: $selectionActionSender,
            onAllTracksAction: onAllTracksAction,
            onCollectionTracksAction: onCollectionTracksAction
        )
    }
}
