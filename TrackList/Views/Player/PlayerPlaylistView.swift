//
//  PlayerPlaylistView.swift
//  TrackList
//
//  Обёртка над PlayerView — передача состояния Player Flow
//  Передаёт данные в UI и управляет действиями
//
//  Created by Pavel Fomin on 15.07.2025.
//

import SwiftUI

struct PlayerPlaylistView: View {
    @ObservedObject var screenViewModel: PlayerScreenViewModel
    
    var body: some View {
        PlayerView(
            rows: screenViewModel.state.rows,
            scrollTargetId: screenViewModel.state.scrollTargetId,
            onTrackTap: { queueItemId in
                screenViewModel.handle(
                    .playPause(queueItemId: queueItemId)
                )
            },
            onMoveTracks: { from, to in
                screenViewModel.handle(
                    .moveTracks(
                        from: from,
                        to: to
                    )
                )
            },
            onDeleteTrack: { queueItemId in
                screenViewModel.handle(
                    .deleteTrack(
                        queueItemId: queueItemId
                    )
                )
            },
            onShowInLibrary: { queueItemId in
                screenViewModel.handle(
                    .showInLibrary(
                        queueItemId: queueItemId
                    )
                )
            },
            onMoveToFolder: { queueItemId in
                screenViewModel.handle(
                    .moveToFolder(
                        queueItemId: queueItemId
                    )
                )
            },
            onAddToTrackList: { queueItemId in
                screenViewModel.handle(
                    .addToTrackList(
                        queueItemId: queueItemId
                    )
                )
            },
            onGoToArtist: { queueItemId in
                screenViewModel.handle(
                    .goToArtist(
                        queueItemId: queueItemId
                    )
                )
            },
            onGoToAlbum: { queueItemId in
                screenViewModel.handle(
                    .goToAlbum(
                        queueItemId: queueItemId
                    )
                )
            },
            onShareTrack: { queueItemId in
                screenViewModel.handle(
                    .shareTrack(
                        queueItemId: queueItemId
                    )
                )
            },
            onCopyTrack: { queueItemId in
                screenViewModel.handle(
                    .copyTrack(
                        queueItemId: queueItemId
                    )
                )
            },
            onEditTags: { queueItemId in
                screenViewModel.handle(
                    .editTags(
                        queueItemId: queueItemId
                    )
                )
            },
            onArtworkTap: { queueItemId in
                screenViewModel.handle(
                    .artworkTap(
                        queueItemId: queueItemId
                    )
                )
            },
            onRequestSnapshot: { trackId in
                screenViewModel.handle(
                    .requestSnapshot(
                        trackId: trackId
                    )
                )
            },
            onRenameTrack: { queueItemId, strategy in
                screenViewModel.handle(
                    .renameTrack(
                        queueItemId: queueItemId,
                        strategy: strategy
                    )
                )
            }
        )
    }
}
