//
//  TrackShareActionHandler.swift
//  TrackList
//
//  Презентует системное меню «Поделиться» после подготовки одного файла.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import UIKit

/// Выполняет единый presentation-flow отправки одного локального или iTunes-трека.
@MainActor
final class TrackShareActionHandler {

    // MARK: - Singleton

    /// Общий handler не позволяет разным экранам дублировать подготовку и очистку файла.
    static let shared = TrackShareActionHandler()

    // MARK: - Dependencies

    /// Сервис не зависит от UIKit и выполняет файловую подготовку вне View.
    private let preparationService: TrackSharePreparationService
    /// Провайдер определяет верхний контроллер для системных окон iOS.
    private let viewControllerProvider: any ViewControllerProviding
    /// Существующий механизм сообщений используется для ошибок локальных файлов.
    private let toastPresenter: any ToastPresenting

    /// Новая операция запрещена, пока предыдущий UIActivityViewController владеет файлом.
    private var isShareOperationRunning = false

    // MARK: - Init

    /// Создаёт production handler внутри MainActor, где доступны UIKit-зависимости приложения.
    private init() {
        self.preparationService = TrackSharePreparationService()
        self.viewControllerProvider = ApplicationViewControllerProvider()
        self.toastPresenter = ToastManager.shared
    }

    /// Создаёт handler с явными зависимостями для изолированных проверок.
    init(
        preparationService: TrackSharePreparationService,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.preparationService = preparationService
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    // MARK: - Actions

    /// Отправляет обычный локальный или imported-трек, доступный через существующую bookmark-модель.
    func shareLocalTrack(
        trackID: UUID
    ) {
        startSharing(.local(trackID: trackID))
    }

    /// Отправляет iTunes-трек через временную материальную копию вместо ipod-library URL.
    func sharePurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack
    ) {
        startSharing(.purchasedITunes(track))
    }

    /// Выбирает источник вне View, сохраняя один flow для очереди и треклистов со смешанными треками.
    func share(
        _ track: any TrackDisplayable
    ) {
        if let purchasedSource = track as? any PurchasedITunesTrackRepresentable,
           purchasedSource.source == .purchasedITunes {
            guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else {
                presentUnavailableAlert()
                return
            }

            sharePurchasedITunesTrack(purchasedTrack)
            return
        }

        shareLocalTrack(trackID: track.trackId)
    }

    // MARK: - Private

    /// Источник выбирается handler-ом, поэтому View не ищет файл и не различает его тип.
    private enum ShareSource {
        case local(trackID: UUID)
        case purchasedITunes(PurchasedITunesPlayableTrack)
    }

    /// Запускает ровно одну подготовку и сохраняет файл до системного callback завершения.
    private func startSharing(
        _ source: ShareSource
    ) {
        guard isShareOperationRunning == false else { return }

        isShareOperationRunning = true

        Task {
            do {
                let preparedFile: PreparedTrackShareFile
                switch source {
                case .local(let trackID):
                    preparedFile = try await preparationService.prepareLocalTrack(
                        trackID: trackID
                    )
                case .purchasedITunes(let track):
                    preparedFile = try await preparationService.preparePurchasedITunesTrack(
                        track
                    )
                }

                presentShareSheet(for: preparedFile)
            } catch {
                isShareOperationRunning = false
                presentPreparationError(error)
            }
        }
    }

    /// Показывает стандартный UIActivityViewController с исходным или временно подготовленным аудиофайлом.
    private func presentShareSheet(
        for preparedFile: PreparedTrackShareFile
    ) {
        let preparationService = self.preparationService

        guard let presenter = viewControllerProvider.topViewController() else {
            isShareOperationRunning = false
            Task {
                await preparationService.finishSharing(preparedFile)
            }
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        let activityController = UIActivityViewController(
            activityItems: [preparedFile.fileURL],
            applicationActivities: nil
        )
        activityController.completionWithItemsHandler = { [weak self, preparationService] _, _, _, _ in
            // Файл остаётся доступным до завершения системного меню, включая отмену пользователем.
            Task {
                await preparationService.finishSharing(preparedFile)
                await MainActor.run {
                    self?.isShareOperationRunning = false
                }
            }
        }

        if let popover = activityController.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = presenter.view.bounds
        }

        presenter.present(activityController, animated: true)
    }

    /// Отображает недоступность iTunes-трека требуемым alert, а не техническую ошибку AVFoundation.
    private func presentPreparationError(
        _ error: Error
    ) {
        guard let error = error as? TrackSharePreparationError else {
            toastPresenter.handle(.fileAccessDenied)
            return
        }

        switch error {
        case .purchasedITunesUnavailable:
            presentUnavailableAlert()
        case .bookmarkUnavailable:
            toastPresenter.handle(.bookmarkResolveFailed)
        case .localFileUnavailable:
            toastPresenter.handle(.fileNotFound)
        case .localFileAccessDenied:
            toastPresenter.handle(.fileAccessDenied)
        }
    }

    /// Показывает единый alert для облачных, защищённых и неэкспортируемых iTunes-треков.
    private func presentUnavailableAlert() {
        guard let presenter = viewControllerProvider.topViewController() else {
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        let alert = UIAlertController(
            title: TrackSharePresentationText.unavailableTitle,
            message: TrackSharePresentationText.unavailableMessage,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: TrackSharePresentationText.acknowledgeTitle,
                style: .default
            )
        )
        presenter.present(alert, animated: true)
    }
}
