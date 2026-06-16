//
//  TrackListsPresenting.swift
//  TrackList
//
//  Контракт презентации действий списка треклистов.
//
//  Created by Pavel Fomin on 16.06.2026.
//

import Foundation

@MainActor
protocol TrackListsPresenting {

    /// Показывает экран создания нового треклиста.
    func presentCreateTrackList()
}
