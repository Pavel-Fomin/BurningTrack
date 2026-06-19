//
//  NotificationPlayerEventObserver.swift
//  TrackList
//
//  Источник событий плеера на базе NotificationCenter.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Преобразует уведомления NotificationCenter в события PlayerViewModel.
final class NotificationPlayerEventObserver: PlayerEventObserving {

    var onTrackDurationUpdated: ((TimeInterval) -> Void)?

    var onTrackDidFinish: (() -> Void)?

    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)?

    var onSettingsChanged: (() -> Void)?

    private let notificationCenter: NotificationCenter
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    /// Создаёт источник событий и сразу подписывается на нужные уведомления.
    nonisolated init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observeEvents()
    }

    deinit {
        observers.forEach { observer in
            notificationCenter.removeObserver(observer)
        }
    }

    /// Регистрирует все NotificationCenter-подписки, нужные PlayerViewModel.
    nonisolated private func observeEvents() {
        let durationObserver = notificationCenter.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let duration = notification.userInfo?["duration"] as? TimeInterval else { return }

            Task { @MainActor in
                self?.onTrackDurationUpdated?(duration)
            }
        }

        let finishObserver = notificationCenter.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onTrackDidFinish?()
            }
        }

        let updateObserver = notificationCenter.addObserver(
            forName: .trackDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let updateEvent = notification.object as? TrackUpdateEvent else { return }

            Task { @MainActor in
                self?.onTrackDidUpdate?(updateEvent)
            }
        }

        let settingsObserver = notificationCenter.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onSettingsChanged?()
            }
        }

        observers = [
            durationObserver,
            finishObserver,
            updateObserver,
            settingsObserver
        ]
    }
}
