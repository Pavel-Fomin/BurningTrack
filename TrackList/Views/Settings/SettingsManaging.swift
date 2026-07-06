//
//  SettingsManaging.swift
//  TrackList
//
//  Контракт чтения и изменения рабочих настроек приложения.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Combine

@MainActor
protocol SettingsManaging: AnyObject {
    var settings: AppSettings { get }
    var settingsPublisher: Published<AppSettings>.Publisher { get }

    func setTagReadingEnabled(_ value: Bool)
    func setTrackListMembershipVisible(_ value: Bool)
    func setFileFormatVisible(_ value: Bool)
    func setPurchasedITunesSourceVisible(_ value: Bool)
    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws
    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws
    func setLibraryFoldersSortMode(_ mode: LibraryFoldersSortMode?) throws
}
