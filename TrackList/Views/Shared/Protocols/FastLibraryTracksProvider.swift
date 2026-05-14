//
//  FastLibraryTracksProvider.swift
//  TrackList
//
//  Быстрый provider для первичного отображения треков фонотеки.
//
//  Роль:
//  - берёт треки только из TrackRegistry;
//  - не восстанавливает bookmark;
//  - не обращается к файловой системе;
//  - не читает даты файла через resourceValues;
//  - используется для моментального показа списка.
//
//  Created by Pavel Fomin on 14.05.2026.
//

import Foundation

final class FastLibraryTracksProvider: LibraryTracksProvider {

    func tracks(inFolder folderId: UUID) async -> [LibraryTrack] {
        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)

        return entries.map { entry in
            let fileURL = URL(fileURLWithPath: entry.relativePath)

            return LibraryTrack(
                id: entry.id,
                fileURL: fileURL,
                title: nil,
                artist: nil,
                duration: 0,
                addedDate: entry.fileDate,
                isAvailable: true
            )
        }
    }
}
