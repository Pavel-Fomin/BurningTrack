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

    /// ViewModel владеет загрузкой и сортировкой, а handler принимает typed-намерения View.
    private let viewModel: PurchasedITunesMusicViewModel
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    // MARK: - Init

    /// Создаёт обработчик с production- или тестовыми зависимостями.
    init(
        viewModel: PurchasedITunesMusicViewModel,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.viewModel = viewModel
        self.exportRequestHandler = exportRequestHandler
    }

    // MARK: - Handle

    /// Выполняет действие экрана за пределами SwiftUI View.
    func handle(
        _ action: PurchasedITunesMusicAction
    ) {
        switch action {
        case .appeared:
            loadTracks()

        case .sortModeSelected(let mode):
            viewModel.selectSortMode(mode)

        case .exportTracks:
            exportTracks(viewModel.screenState.tracks)
        }
    }

    /// Запускает загрузку вне SwiftUI View и сохраняет текущую асинхронную семантику экрана.
    private func loadTracks() {
        Task { [viewModel] in
            await viewModel.load()
        }
    }

    // MARK: - Export

    /// Запускает обычный экспорт всех доступных iTunes-треков без нумерации.
    private func exportTracks(
        _ purchasedTracks: [PurchasedITunesPlayableTrack]
    ) {
        // ExportRequest сохраняет transport-модель Track с отдельным iTunes source.
        // Адаптер сохраняет source и assetURL, поэтому ExportJob сразу выбирает
        // iTunes-ветку и не обращается к BookmarkResolver.
        let exportTracks = purchasedTracks.map(
            Track.init(purchasedITunesTrack:)
        )
        exportRequestHandler.startExport(
            ExportRequest(
                tracks: exportTracks,
                exportFolder: .purchasedITunes,
                fileNamingMode: .original
            )
        )
    }
}
