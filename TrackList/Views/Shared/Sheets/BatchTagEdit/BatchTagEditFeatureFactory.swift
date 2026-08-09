//
//  BatchTagEditFeatureFactory.swift
//  TrackList
//
//  Собирает production-граф сценария Batch Tag Edit.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Собирает feature-local MVVM граф из явных production-зависимостей.
@MainActor
struct BatchTagEditFeatureFactory {
    /// Загружает исходный metadata draft выбранных треков.
    private let metadataLoader: any BatchTagEditMetadataLoading
    /// Выполняет существующие команды записи тегов.
    private let saveExecutor: any BatchTagEditSaveExecuting
    /// Предоставляет актуальные artwork из runtime snapshot.
    private let artworkDataProvider: any BatchTagArtworkDataProviding
    /// Нормализует replacement artwork.
    private let artworkPreparer: any BatchTagArtworkPreparing
    /// Сжимает artwork выбранным domain-алгоритмом.
    private let artworkCompressor: any BatchTagArtworkCompressing
    /// Показывает общий ToastEvent результата сохранения.
    private let toastPresenter: any ToastPresenting
    /// Открывает и закрывает sheet через глобальный lifecycle.
    private let router: any BatchTagEditRouting

    init(
        metadataLoader: any BatchTagEditMetadataLoading,
        saveExecutor: any BatchTagEditSaveExecuting,
        artworkDataProvider: any BatchTagArtworkDataProviding,
        artworkPreparer: any BatchTagArtworkPreparing,
        artworkCompressor: any BatchTagArtworkCompressing,
        toastPresenter: any ToastPresenting,
        router: any BatchTagEditRouting
    ) {
        self.metadataLoader = metadataLoader
        self.saveExecutor = saveExecutor
        self.artworkDataProvider = artworkDataProvider
        self.artworkPreparer = artworkPreparer
        self.artworkCompressor = artworkCompressor
        self.toastPresenter = toastPresenter
        self.router = router
    }

    /// Создаёт один стабильный StateObject-контейнер по immutable route payload.
    func makeView(data: BatchTagEditSheetData) -> BatchTagEditContainer {
        let presenter = BatchTagEditPresenter(toastPresenter: toastPresenter)
        let actionHandler = BatchTagEditActionHandler(
            metadataLoader: metadataLoader,
            saveExecutor: saveExecutor,
            artworkDataProvider: artworkDataProvider,
            artworkPreparer: artworkPreparer,
            artworkCompressor: artworkCompressor,
            presenter: presenter,
            router: router
        )
        let viewModel = BatchTagEditViewModel(
            sheetData: data,
            presenter: presenter,
            actionHandler: actionHandler
        )
        return BatchTagEditContainer(viewModel: viewModel)
    }
}
