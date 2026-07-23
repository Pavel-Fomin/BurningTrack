//
//  PurchasedITunesMusicActionHandler.swift
//  TrackList
//
//  Обработчик действий экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Направляет экспорт iTunes-треков в существующее глобальное состояние Export.
@MainActor
final class PurchasedITunesMusicActionHandler {

    // MARK: - Dependencies

    /// Глобальный владелец picker-а, progress и жизненного цикла экспорта.
    private let exportProgressViewModel: ExportProgressViewModel
    /// Предоставляет presenter существующего системного выбора папки.
    private let viewControllerProvider: any ViewControllerProviding
    /// Показывает ошибку, если picker нельзя презентовать.
    private let toastPresenter: any ToastPresenting

    // MARK: - Init

    /// Создаёт обработчик с production- или тестовыми зависимостями.
    init(
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.exportProgressViewModel = exportProgressViewModel
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    // MARK: - Handle

    /// Выполняет действие экрана за пределами SwiftUI View.
    func handle(
        _ action: PurchasedITunesMusicAction
    ) {
        switch action {
        case .exportTracks(let tracks):
            exportTracks(tracks)
        }
    }

    // MARK: - Export

    /// Запускает обычный экспорт всех доступных iTunes-треков без нумерации.
    private func exportTracks(
        _ purchasedTracks: [PurchasedITunesPlayableTrack]
    ) {
        guard purchasedTracks.isEmpty == false else { return }

        guard let presenter = viewControllerProvider.topViewController() else {
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        // Существующая глобальная ViewModel принимает transport-модель Track.
        // Адаптер сохраняет source и assetURL, поэтому ExportJob сразу выбирает
        // iTunes-ветку и не обращается к BookmarkResolver.
        let exportTracks = purchasedTracks.map(
            Track.init(purchasedITunesTrack:)
        )
        exportProgressViewModel.startExport(
            tracks: exportTracks,
            exportFolderName: "Куплено в iTunes",
            fileNamingMode: .original,
            presenter: presenter
        )
    }
}
