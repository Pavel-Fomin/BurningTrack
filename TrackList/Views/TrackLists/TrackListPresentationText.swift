//
//  TrackListPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя треклистов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует смысловые данные треклистов в локализованные подписи интерфейса.
enum TrackListPresentationText {

    /// Возвращает локализованное системное название или сохранённое пользовательское имя треклиста.
    static func title(
        for kind: TrackListKind,
        storedName: String
    ) -> String {
        switch kind {
        case .regular:
            return storedName
        case .favorites:
            return String(localized: "tracklist.favorites.title")
        }
    }

    /// Возвращает названия только пользовательских треклистов для дополнительной строки трека.
    ///
    /// Системное «Избранное» не является пользовательской меткой трека и не показывается в строках фонотеки и поиска.
    static func membershipTitles(
        for memberships: [TrackListMembership]
    ) -> [String] {
        memberships.compactMap { membership in
            guard membership.kind == .regular else {
                return nil
            }

            return title(
                for: membership.kind,
                storedName: membership.storedName
            )
        }
    }

    static var goToArtist: String {
        String(localized: "Go to Artist")
    }

    static var goToAlbum: String {
        String(localized: "Go to Album")
    }

    /// Форматирует дату создания треклиста без времени в текущей системной locale.
    private static let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Возвращает заголовок режима сортировки в меню списка треклистов.
    static func sortTitle(for mode: TrackListsSortMode) -> String {
        switch mode {
        case .createdAt:
            return String(localized: "By Date")
        case .name:
            return String(localized: "By Name")
        }
    }

    /// Возвращает вторичную подпись активного режима сортировки.
    static func sortCaption(for mode: TrackListsSortMode) -> String {
        switch mode {
        case .createdAt:
            return String(localized: "by date")
        case .name:
            return String(localized: "by name")
        }
    }

    /// Форматирует дату создания треклиста без времени.
    static func createdAt(_ date: Date) -> String {
        createdAtFormatter.string(from: date)
    }

    /// Возвращает дату создания только для пользовательского треклиста.
    ///
    /// Системный треклист «Избранное» определяется по назначению, а не по сохранённому имени,
    /// поэтому его служебная дата создания не показывается в интерфейсе.
    static func createdAt(
        for kind: TrackListKind,
        date: Date
    ) -> String? {
        guard kind == .regular else {
            return nil
        }

        return createdAt(date)
    }

    /// Форматирует количество треков через общий plural-ключ статистики.
    static func trackCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "library.trackCount"),
            count
        )
    }

    /// Форматирует количество выбранных треков через общий plural-ключ панели выбора.
    static func selectedTracksCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "library.selection.trackCount"),
            count
        )
    }

    static func savedMessage(name: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.tracklist.saved"),
            name
        )
    }

    static var createdMessage: String {
        String(localized: "toast.tracklist.created")
    }

    static var clearedMessage: String {
        String(localized: "toast.tracklist.cleared")
    }

    static func tracksAddedMessage(count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.tracklist.tracksAdded"),
            count
        )
    }

    static func trackAddedMessage(name: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.tracklist.trackAdded"),
            name
        )
    }

    static var trackRemovedMessage: String {
        String(localized: "toast.tracklist.trackRemoved")
    }

    static var renamedMessage: String {
        String(localized: "toast.tracklist.renamed")
    }

    static var notFoundMessage: String {
        String(localized: "toast.tracklist.notFound")
    }

    static var loadFailedMessage: String {
        String(localized: "toast.tracklist.loadFailed")
    }

    static var saveFailedMessage: String {
        String(localized: "toast.tracklist.saveFailed")
    }

    static var invalidNameMessage: String {
        String(localized: "toast.tracklist.invalidName")
    }

    /// Возвращает сообщение о запрете переименования системного треклиста.
    static var favoritesRenameNotAllowedMessage: String {
        String(localized: "toast.tracklist.favoritesRenameNotAllowed")
    }

    /// Возвращает сообщение о запрете удаления системного треклиста.
    static var favoritesDeletionNotAllowedMessage: String {
        String(localized: "toast.tracklist.favoritesDeletionNotAllowed")
    }

    /// Возвращает сообщение о запрете перемещения системного треклиста.
    static var favoritesReorderNotAllowedMessage: String {
        String(localized: "toast.tracklist.favoritesReorderNotAllowed")
    }

    static var defaultTrackListName: String {
        String(localized: "Tracklist")
    }
}

extension TrackListsRowState {

    /// Дата создания показывается только у пользовательского треклиста.
    var createdAtText: String? {
        TrackListPresentationText.createdAt(
            for: trackList.kind,
            date: createdAt
        )
    }

    /// Количество треков формируется только в presentation-слое.
    var tracksCountText: String {
        TrackListPresentationText.trackCount(tracksCount)
    }
}
