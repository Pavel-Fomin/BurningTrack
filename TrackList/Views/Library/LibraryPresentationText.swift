//
//  LibraryPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя фонотеки.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Сопоставляет смысловые значения фонотеки с локализованными подписями интерфейса.
enum LibraryPresentationText {
    static func rootDisplayModeTitle(for mode: LibraryRootDisplayMode) -> String {
        switch mode {
        case .folders:
            return String(localized: "Folders")
        case .tracks:
            return String(localized: "Tracks")
        }
    }

    static func collectionCategoryTitle(for category: LibraryCollectionCategory) -> String {
        switch category {
        case .artists:
            return String(localized: "Artists")
        case .albums:
            return String(localized: "Albums")
        case .genres:
            return String(localized: "Genres")
        case .labels:
            return String(localized: "Labels")
        case .years:
            return String(localized: "Years")
        }
    }

    static func collectionRootItemTitle(for item: LibraryCollectionRootItem) -> String {
        switch item {
        case .allTracks:
            return String(localized: "Tracks")
        case .category(let category):
            return collectionCategoryTitle(for: category)
        }
    }

    static func folderSortModeTitle(for mode: LibraryFoldersSortMode) -> String {
        switch mode {
        case .createdAt:
            return String(localized: "By Date")
        case .name:
            return String(localized: "By Name")
        }
    }

    static func folderSortModeCaption(for mode: LibraryFoldersSortMode) -> String {
        switch mode {
        case .createdAt:
            return String(localized: "by date")
        case .name:
            return String(localized: "by name")
        }
    }

    static func trackSortModeTitle(for mode: LibraryTrackSortMode) -> String {
        switch mode {
        case .artistAsc:
            return String(localized: "Artist A–Z")
        case .artistDesc:
            return String(localized: "Artist Z–A")
        case .titleAsc:
            return String(localized: "Title A–Z")
        case .titleDesc:
            return String(localized: "Title Z–A")
        case .albumAsc:
            return String(localized: "Album A–Z")
        case .albumDesc:
            return String(localized: "Album Z–A")
        case .yearDesc:
            return String(localized: "Year: Newest First")
        case .yearAsc:
            return String(localized: "Year: Oldest First")
        case .labelAsc:
            return String(localized: "Label A–Z")
        case .labelDesc:
            return String(localized: "Label Z–A")
        case .genreAsc:
            return String(localized: "Genre A–Z")
        case .genreDesc:
            return String(localized: "Genre Z–A")
        case .commentAsc:
            return String(localized: "Comment")
        case .fileNameAsc:
            return String(localized: "File Name A–Z")
        case .fileNameDesc:
            return String(localized: "File Name Z–A")
        case .fileDateDesc:
            return String(localized: "Date: Newest First")
        case .fileDateAsc:
            return String(localized: "Date: Oldest First")
        }
    }

    static func collectionValueSortModeTitle(for mode: LibraryCollectionValueSortMode) -> String {
        switch mode {
        case .titleAscending,
             .artistAscending:
            return String(localized: "A–Z")
        case .titleDescending,
             .artistDescending:
            return String(localized: "Z–A")
        case .yearNewestFirst:
            return String(localized: "Newest First")
        case .yearOldestFirst:
            return String(localized: "Oldest First")
        }
    }

    static func collectionValueSortMenuGroupTitle(
        for group: LibraryCollectionValueSortMode.MenuGroup
    ) -> String {
        switch group {
        case .title:
            return String(localized: "By Name")
        case .year:
            return String(localized: "By Year")
        case .artist:
            return String(localized: "By Artist")
        }
    }

    static func bulkActionTitle(for action: BulkTrackAction) -> String {
        switch action {
        case .addToPlayer:
            return String(localized: "Add to Player")
        case .addToTrackList:
            return String(localized: "Add to Tracklist")
        case .renameFiles:
            return String(localized: "File Name")
        case .editTags:
            return String(localized: "Tags")
        }
    }

    static var trackActionMenuLabels: TrackActionMenuLabels {
        TrackActionMenuLabels(
            trackInfo: String(localized: "Track Info"),
            move: String(localized: "Move"),
            addToPlayer: String(localized: "Add to Player"),
            addToTracklist: String(localized: "Add to Tracklist"),
            tags: String(localized: "Tags"),
            fileName: String(localized: "File Name"),
            edit: String(localized: "Edit")
        )
    }

    static func sourceNavigationTitle(for source: LibraryTrackListSource) -> String {
        switch source {
        case .folder:
            return String(localized: "Tracks")
        case .allLibraryTracks:
            return String(localized: "Tracks")
        case .collectionValue(_, let rawValue, _):
            return rawValue
        }
    }

    static func selectedTrackCountText(for count: Int) -> String {
        let format = String(localized: "library.selection.trackCount")
        return String.localizedStringWithFormat(format, count)
    }

    static var folderAddedMessage: String {
        String(localized: "toast.library.folderAdded")
    }

    static var folderRemovedMessage: String {
        String(localized: "toast.library.folderRemoved")
    }

    static var folderPickFailedMessage: String {
        String(localized: "toast.library.folderPickFailed")
    }

    static var folderAddFailedMessage: String {
        String(localized: "toast.library.folderAddFailed")
    }

    static var folderDetachFailedMessage: String {
        String(localized: "toast.library.folderDetachFailed")
    }

    static var displayModeSaveFailedMessage: String {
        String(localized: "toast.library.displayModeSaveFailed")
    }

    static var folderOrderSaveFailedMessage: String {
        String(localized: "toast.library.folderOrderSaveFailed")
    }

    static var libraryAccessNeedsRestoreMessage: String {
        String(localized: "toast.library.accessNeedsRestore")
    }

    static var libraryAccessDeniedMessage: String {
        String(localized: "toast.library.accessDenied")
    }

    static var libraryFolderUnavailableMessage: String {
        String(localized: "toast.library.folderUnavailable")
    }

    static var libraryRestoreFailedMessage: String {
        String(localized: "toast.library.restoreFailed")
    }

    static var librarySyncFailedMessage: String {
        String(localized: "toast.library.syncFailed")
    }

    static var folderNotFoundMessage: String {
        String(localized: "Folder Not Found")
    }

    static var showInLibraryTargetMissingMessage: String {
        String(localized: "toast.library.showInLibraryTargetMissing")
    }

    static var importFailedMessage: String {
        String(localized: "toast.library.importFailed")
    }

    static var importPartiallyFailedMessage: String {
        String(localized: "toast.library.importPartiallyFailed")
    }

    static func partialImportDetails(
        imported: Int,
        failed: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.library.partialImportDetails"),
            imported,
            failed
        )
    }
}
