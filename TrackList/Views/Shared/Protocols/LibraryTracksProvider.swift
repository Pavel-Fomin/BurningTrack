//
//  LibraryTracksProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


protocol LibraryTracksProvider {
    func tracks(inFolder folderId: UUID) async -> [LibraryTrack]
}
