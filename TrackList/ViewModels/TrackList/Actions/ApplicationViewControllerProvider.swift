//
//  ApplicationViewControllerProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import UIKit

/// Production-провайдер верхнего UIViewController.
@MainActor
final class ApplicationViewControllerProvider: ViewControllerProviding {
    func topViewController() -> UIViewController? {
        UIApplication.topViewController()
    }
}
