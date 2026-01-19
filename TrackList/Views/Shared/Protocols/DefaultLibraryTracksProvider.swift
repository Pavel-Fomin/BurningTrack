//
//  DefaultLibraryTracksProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


final class DefaultLibraryTracksProvider: LibraryTracksProvider {

    func tracks(inFolder folderId: UUID) async -> [LibraryTrack] {

        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)
        var result: [LibraryTrack] = []
        result.reserveCapacity(entries.count)

        for entry in entries {
            guard let url = await BookmarkResolver.url(forTrack: entry.id) else { continue }

            var fileDate = entry.updatedAt
            if let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .creationDateKey]
            ) {
                fileDate =
                    values.contentModificationDate ??
                    values.creationDate ??
                    entry.updatedAt
            }

            result.append(
                LibraryTrack(
                    id: entry.id,
                    fileURL: url,
                    title: nil,
                    artist: nil,
                    duration: 0,
                    addedDate: fileDate
                )
            )
        }

        return result
    }
}
