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

    /// Store удерживает graph выбранного источника и не пересобирается при обновлении родительского View.
    @StateObject private var screenStore: LibraryCollectionTracksScreenStore

    init(
        factory: LibraryTracksScreenFactory,
        source: LibraryTrackListSource,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.source = source
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
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
            onAllTracksAction: makeAllTracksActionSender(),
            onCollectionTracksAction: makeCollectionTracksActionSender()
        )
    }

    /// Передаёт общий экспорт в handler, созданный вместе с destination graph.
    private func makeAllTracksActionSender() -> ((LibraryAllTracksAction) -> Void)? {
        guard let handler = screenStore.allTracksActionHandler else { return nil }
        return { action in
            handler.handle(action)
        }
    }

    /// Передаёт экспорт значения коллекции в handler, созданный вместе с destination graph.
    private func makeCollectionTracksActionSender() -> ((LibraryCollectionTracksAction) -> Void)? {
        guard let handler = screenStore.collectionTracksActionHandler else { return nil }
        return { action in
            handler.handle(action)
        }
    }
}
