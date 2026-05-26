//
//  BatchFilenameRenameContainer.swift
//  TrackList
//
//  Контейнер массового переименования файлов.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import SwiftUI

/// Контейнер массового переименования файлов.
///
/// Контейнер отвечает за:
/// - единый заголовок sheet;
/// - закрытие sheet;
/// - передачу действий во flow;
/// - соблюдение общего контракта sheet’ов проекта.
struct BatchFilenameRenameContainer: View {

    // MARK: - State

    /// Flow массового переименования файлов.
    @ObservedObject var flow: BatchFilenameRenameFlow

    /// Менеджер плеера нужен командному слою для проверки занятого файла.
    let playerManager: PlayerManager

    /// Применение подготовленного плана переименования.
    let onApply: () async -> Void

    /// Закрытие sheet’а из родительского экрана.
    let onClose: () -> Void

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Изменение имени файла",
            subtitle: "Из тегов",
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(!flow.isBusy),
            onClose: {
                guard !flow.isBusy else { return }
                onClose()
            },
            onRightTap: {
                guard !flow.isBusy else { return }
                onClose()
            }
        ) {
            BatchFilenameRenameSheet(
                flow: flow,
                canApplyRename: flow.canApplyRename,
                onSelectStrategy: { strategy in
                    guard !flow.isBusy else { return }
                    guard flow.phase != .loadingMetadata else { return }
                    flow.buildPlan(
                        strategy: strategy,
                        tracks: flow.tracks
                    )
                },
                onRemoveTrack: { trackId in
                    guard !flow.isBusy else { return }
                    flow.removeTrack(id: trackId)
                },
                onRename: {
                    Task {
                        await onApply()
                    }
                }
            )
        }
        .interactiveDismissDisabled(flow.isBusy)
    }
}
