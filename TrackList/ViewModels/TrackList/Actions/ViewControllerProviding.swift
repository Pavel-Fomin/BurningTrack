//
//  ViewControllerProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import UIKit

/// Предоставляет верхний UIViewController для системной презентации.
@MainActor
protocol ViewControllerProviding {
    /// Текущий верхний UIViewController.
    func topViewController() -> UIViewController?
}
