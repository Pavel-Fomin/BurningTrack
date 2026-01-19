//
//  TabResettable.swift
//  TrackList
//
//  Протокол сброса при повторном тапе в меню
//
//  Created by Pavel Fomin on 26.11.2025.
//

import Foundation

@MainActor
protocol TabResettable: AnyObject {
    func resetTab()
}
