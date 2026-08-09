//
//  CreateTrackListFlowFactory.swift
//  TrackList
//
//  Собирает feature-flow создания и выбора треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import SwiftUI

/// Собирает production graph только связанного Create TrackList flow.
@MainActor
struct CreateTrackListFlowFactory {
    /// Доменный фасад создания и пополнения треклистов.
    private let trackListsManager: any TrackListFlowManaging
    /// Презентер пользовательских сообщений flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизатор create-sheet.
    private let createRouter: any CreateTrackListRouting
    /// Маршрутизатор selection-sheet.
    private let selectionRouter: any NewTrackListSelectionRouting
    /// Источник прикреплённых папок для выбора треков.
    private let foldersProvider: any LibraryFoldersProviding
    /// Каноническая factory экранной возможности Library Tracks.
    private let libraryTracksScreenFactory: LibraryTracksScreenFactory
    /// Published-снимок «Избранного» для готового состояния строк выбора.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding

    init(
        trackListsManager: any TrackListFlowManaging,
        toastPresenter: any ToastPresenting,
        createRouter: any CreateTrackListRouting,
        selectionRouter: any NewTrackListSelectionRouting,
        foldersProvider: any LibraryFoldersProviding,
        libraryTracksScreenFactory: LibraryTracksScreenFactory,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.createRouter = createRouter
        self.selectionRouter = selectionRouter
        self.foldersProvider = foldersProvider
        self.libraryTracksScreenFactory = libraryTracksScreenFactory
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
    }

    /// Собирает корневой экран формы создания треклиста.
    func makeCreateTrackListView(
        data: CreateTrackListSheetData
    ) -> CreateTrackListContainer {
        let actionHandler = CreateTrackListActionHandler(
            trackListsManager: trackListsManager,
            toastPresenter: toastPresenter,
            router: createRouter,
            routeID: data.id
        )
        let viewModel = CreateTrackListViewModel(
            stateBuilder: CreateTrackListStateBuilder(),
            actionHandler: actionHandler
        )

        return CreateTrackListContainer(viewModel: viewModel)
    }

    /// Собирает корневой экран выбора треков для create- или append-режима.
    func makeSelectionView(
        data: NewTrackListSelectionSheetData
    ) -> NewTrackListSelectionContainer {
        let actionHandler = NewTrackListSelectionActionHandler(
            mode: data.mode,
            trackListsManager: trackListsManager,
            toastPresenter: toastPresenter,
            router: selectionRouter,
            routeID: data.id
        )
        let viewModel = NewTrackListSelectionViewModel(
            foldersProvider: foldersProvider,
            stateBuilder: NewTrackListSelectionStateBuilder(),
            actionHandler: actionHandler
        )
        let folderViewFactory = NewTrackListSelectionFolderViewFactory(
            libraryTracksScreenFactory: libraryTracksScreenFactory,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider
        )

        return NewTrackListSelectionContainer(
            viewModel: viewModel,
            folderViewFactory: folderViewFactory
        )
    }
}
