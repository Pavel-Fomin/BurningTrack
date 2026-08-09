//
//  BatchTagArtworkEditSection.swift
//  TrackList
//
//  Отображает готовые карточки artwork для массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Leaf-секция artwork без binding к draft и без runtime-зависимостей.
struct BatchTagArtworkEditSection: View {
    /// Готовые данные карточек и прогресса artwork.
    let state: BatchTagEditArtworkScreenState
    /// Typed-канал всех изменений feature.
    let send: (BatchTagEditAction) -> Void
    /// Открывает системный picker после передачи action во ViewModel.
    let onReplaceRequested: (BatchTagArtworkActionTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            previewScroll
            if let compressionFailureText = state.compressionFailureText {
                Text(compressionFailureText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
            if let progress = state.preparationProgress {
                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .padding(.horizontal, 16)
            }
        }
    }

    /// Горизонтальный список карточек, полностью собранных Presenter-ом.
    private var previewScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                BatchTagArtworkSummaryCard(
                    state: state.summary,
                    onSelect: {
                        send(.artworkTargetSelected(.summary))
                    },
                    onMenuAction: handleMenuAction
                )
                ForEach(state.cards) { card in
                    BatchTagArtworkPreviewCard(
                        state: card,
                        onSelect: {
                            send(.artworkTargetSelected(.track(card.trackId)))
                        },
                        onMenuAction: { action in
                            handleMenuAction(action, target: .track(card.trackId))
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Переводит UI-меню в feature actions, не позволяя карточкам менять draft напрямую.
    private func handleMenuAction(
        _ action: BatchTagArtworkMenuAction,
        target: BatchTagArtworkActionTarget
    ) {
        switch action {
        case .remove:
            send(.artworkRemoveTapped(target: target))
        case .replace:
            onReplaceRequested(target)
        case .compress(let option):
            send(.artworkCompressTapped(target: target, option: option))
        }
    }
}
