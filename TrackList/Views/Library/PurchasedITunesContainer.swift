//
//  PurchasedITunesContainer.swift
//  TrackList
//
//  Удерживает граф destination экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import SwiftUI

/// Создаёт ScreenStore один раз для identity destination и передаёт View только state и actions.
struct PurchasedITunesContainer: View {

    /// Store владеет ViewModel и handler-ами, поэтому повторный body не пересобирает feature graph.
    @StateObject private var store: PurchasedITunesScreenStore
    /// Маршрут раскрытия принадлежит LibraryScreenViewModel и остаётся входом destination.
    let revealRequest: LibraryRevealRequest?
    /// Подтверждает владельцу маршрута завершение физической прокрутки.
    let onRevealHandled: (UUID) -> Void

    init(
        featureFactory: PurchasedITunesFeatureFactory,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void
    ) {
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self._store = StateObject(
            wrappedValue: featureFactory.makeScreenStore()
        )
    }

    var body: some View {
        PurchasedITunesMusicView(
            state: store.screenState,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            onAction: { store.handle($0) },
            onTrackAction: { store.handle($0) }
        )
    }
}
