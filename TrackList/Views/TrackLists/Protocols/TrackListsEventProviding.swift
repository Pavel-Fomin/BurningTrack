//
//  TrackListsEventProviding.swift
//  TrackList
//
//  Контракт событий изменения списка треклистов.
//
//  Created by Pavel Fomin on 16.06.2026.
//

import Foundation
import Combine

@MainActor
protocol TrackListsEventProviding {

    /// Событие изменения списка треклистов.
    var trackListsDidChange: AnyPublisher<Void, Never> { get }
}
