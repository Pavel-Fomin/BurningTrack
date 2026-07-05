//
//  TrackMenuActionAvailability.swift
//  TrackList
//
//  Правила доступности пунктов меню трека.
//
//  Created by Codex on 03.07.2026.
//

import Foundation

/// Единая точка, где меню решает, какие пункты показывать для источника и раздела.
struct TrackMenuActionAvailability {

    /// Возвращает доступные пункты меню для указанного источника и раздела.
    ///
    /// Локальные треки сохраняют прежние наборы действий.
    /// iTunes-треки получают только действия с runtime-данными без файловых операций приложения.
    static func availableActions(
        source: TrackSource,
        context: TrackMenuContext
    ) -> Set<TrackMenuAction> {
        switch source {
        case .library:
            return localActions(context: context)

        case .imported:
            return importedActions(context: context)

        case .purchasedITunes:
            return purchasedITunesActions(context: context)
        }
    }

    /// Проверяет, нужно ли показывать конкретный пункт меню.
    static func isAvailable(
        _ action: TrackMenuAction,
        source: TrackSource,
        context: TrackMenuContext
    ) -> Bool {
        availableActions(
            source: source,
            context: context
        )
        .contains(action)
    }

    /// Прежние наборы меню для локальных файлов приложения.
    private static func localActions(
        context: TrackMenuContext
    ) -> Set<TrackMenuAction> {
        switch context {
        case .library:
            return [
                .details,
                .addToPlayer,
                .addToTrackList,
                .moveToFolder,
                .editTags,
                .renameFile
            ]

        case .player:
            return [
                .details,
                .showInLibrary,
                .moveToFolder,
                .addToTrackList,
                .editTags,
                .renameFile,
                .deleteFromPlayer
            ]

        case .trackList:
            return [
                .details,
                .showInLibrary,
                .moveToFolder,
                .editTags,
                .renameFile,
                .deleteFromTrackList
            ]

        case .purchasedITunes:
            return []
        }
    }

    /// Наборы меню для одиночных импортов без привязки к папкам фонотеки.
    private static func importedActions(
        context: TrackMenuContext
    ) -> Set<TrackMenuAction> {
        switch context {
        case .library:
            return []

        case .player:
            return [
                .details,
                .addToTrackList,
                .editTags,
                .renameFile,
                .deleteFromPlayer
            ]

        case .trackList:
            return [
                .details,
                .addToPlayer,
                .editTags,
                .renameFile,
                .deleteFromTrackList
            ]

        case .purchasedITunes:
            return []
        }
    }

    /// Наборы меню для купленных iTunes-треков без файловых действий приложения.
    private static func purchasedITunesActions(
        context: TrackMenuContext
    ) -> Set<TrackMenuAction> {
        switch context {
        case .purchasedITunes:
            return [
                .details,
                .copy,
                .addToTrackList,
                .addToPlayer
            ]

        case .player:
            return [
                .details,
                .copy,
                .addToTrackList,
                .deleteFromPlayer
            ]

        case .trackList:
            return [
                .details,
                .copy,
                .addToPlayer,
                .deleteFromTrackList
            ]

        case .library:
            return []
        }
    }
}
