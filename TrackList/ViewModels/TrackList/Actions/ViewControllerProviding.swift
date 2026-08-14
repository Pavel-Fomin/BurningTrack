//
//  ViewControllerProviding.swift
//  TrackList
//
//  Объявляет платформенную capability получения верхнего UIKit-контроллера.
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
