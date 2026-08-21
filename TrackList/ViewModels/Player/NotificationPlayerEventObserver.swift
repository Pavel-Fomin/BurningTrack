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
@MainActor
final class NotificationPlayerEventObserver: PlayerEventObserving {

    var onTrackDurationUpdated: ((TimeInterval) -> Void)?

    var onTrackDidFinish: (() -> Void)?

    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)?

    var onTrackBatchDidUpdate: (([TrackUpdateEvent]) -> Void)?

    var onSettingsChanged: (() -> Void)?

    // Источник событий целиком принадлежит MainActor: здесь же устанавливаются callbacks
    // и хранятся tokens NotificationCenter. Поэтому lifecycle не требует unsafe-доступа.
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    /// Создаёт источник событий и сразу подписывается на нужные уведомления.
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observeEvents()
    }

    isolated deinit {
        observers.forEach { observer in
            notificationCenter.removeObserver(observer)
        }
    }

    /// Регистрирует все NotificationCenter-подписки, нужные PlayerViewModel.
    private func observeEvents() {
        // NotificationCenter передаёт @Sendable callback без actor isolation.
        // Задача переводит только внешний callback в MainActor-контракт observer;
        // tokens и их lifecycle при этом остаются у единственного владельца.
        let durationObserver = notificationCenter.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let duration = notification.userInfo?["duration"] as? TimeInterval else { return }

            Task { @MainActor [weak self] in
                self?.onTrackDurationUpdated?(duration)
            }
        }

        let finishObserver = notificationCenter.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onTrackDidFinish?()
            }
        }

        let updateObserver = notificationCenter.addObserver(
            forName: .trackDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let updateEvent = notification.object as? TrackUpdateEvent else { return }

            Task { @MainActor [weak self] in
                self?.onTrackDidUpdate?(updateEvent)
            }
        }

        let batchUpdateObserver = notificationCenter.addObserver(
            forName: .trackBatchDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let updateEvents = notification.userInfo?["events"] as? [TrackUpdateEvent] else {
                return
            }

            Task { @MainActor [weak self] in
                self?.onTrackBatchDidUpdate?(updateEvents)
            }
        }

        let settingsObserver = notificationCenter.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onSettingsChanged?()
            }
        }

        observers = [
            durationObserver,
            finishObserver,
            updateObserver,
            batchUpdateObserver,
            settingsObserver
        ]
    }
}
