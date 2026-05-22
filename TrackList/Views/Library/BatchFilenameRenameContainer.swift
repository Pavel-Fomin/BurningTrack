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
/// - передачу действий во ViewModel;
/// - соблюдение общего контракта sheet’ов проекта.
struct BatchFilenameRenameContainer: View {

    // MARK: - State

    /// ViewModel текущего списка треков фонотеки.
    @ObservedObject var viewModel: LibraryTracksViewModel

    /// Менеджер плеера нужен командному слою для проверки занятого файла.
    let playerManager: PlayerManager

    /// Закрытие sheet’а из родительского экрана.
    let onClose: () -> Void

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Изменение имени файла",
            subtitle: "Из тегов",
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(true),
            onClose: {
                onClose()
            },
            onRightTap: {
                onClose()
            }
        ) {
            BatchFilenameRenameSheet(
                flow: viewModel.batchFilenameRenameFlow,
                canApplyRename: viewModel.canApplyBatchFilenameRename,
                onSelectStrategy: { strategy in
                    viewModel.selectFilenameRenameStrategy(strategy)
                },
                onRemoveTrack: { trackId in
                    viewModel.removeTrackFromRenameFlow(trackId)
                },
                onRename: {
                    Task {
                        await viewModel.applyBatchFilenameRename(using: playerManager)
                    }
                }
            )
        }
    }
}
