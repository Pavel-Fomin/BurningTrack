//
//  TrackListBadgeProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


protocol TrackListBadgeProvider {
    func badges(for trackIds: [UUID]) -> [UUID: [String]]
}
