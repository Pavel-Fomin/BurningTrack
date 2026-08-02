//
//  SheetHostModifier.swift
//  TrackList
//
//  Унифицированный контейнер для всех sheet’ов приложения.
//  Отвечает ТОЛЬКО за отображение sheet’ов по AppSheet.
//  Не содержит логики, навигации и обработки действий.
//
//  Command-based UI Architecture:
//  - SheetHost — тупой UI-контейнер
//  - Sheet’ы сами инициируют команды или UI-действия
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI

struct SheetHostModifier: ViewModifier {

    /// Единое presentation-state Sheet, переданное Composition Root.
    @ObservedObject var sheetManager: SheetManager
    /// Единый presentation-state Toast, переданный Composition Root.
    let toastManager: ToastManager

    /// Published-снимок «Избранного» нужен только sheet выбора треков.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Проверяет занятость файла без передачи Sheet-сценариям PlayerManager.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает текущий файл через согласованное playback-состояние.
    let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Готовый обработчик переименования файла для sheet выбора треков.
    let renameActionHandler: TrackFileRenameActionHandler

    func body(content: Content) -> some View {
        content
            .sheet(
                item: $sheetManager.activeSheet,
                onDismiss: {
                    sheetManager.handleDismiss()
                }
            ) { sheet in switch sheet {
                
                // MARK: - Действия над треком
                
                /// Сохранение треклиста
            case .saveTrackList:
                SaveTrackListContainer()
                    .appSheet(detents: [.fraction(0.45), .medium])
                
                /// Переименование треклиста
            case .renameTrackList(let data):
                RenameTrackListContainer(data: data)
                    .appSheet(detents: [.fraction(0.45), .medium])

                /// Ручное переименование файла трека
            case .renameTrackFile(let data):
                RenameTrackFileContainer(
                    data: data,
                    fileBusyChecker: fileBusyChecker,
                    playbackFileReleaser: playbackFileReleaser
                )
                .appSheet(detents: [.fraction(0.45), .medium])
                .toastHost(toastManager: toastManager)
                
                /// Перемещение трека
            case .moveToFolder(let data):
                MoveToFolderContainer(
                    data: data,
                    fileBusyChecker: fileBusyChecker
                )
                .appSheet(detents: [.fraction(0.6), .medium])
                
                /// О треке
            case .trackDetail(let track):
                    TrackDetailContainer(
                        track: track,
                        fileBusyChecker: fileBusyChecker,
                        playbackFileReleaser: playbackFileReleaser
                    )
                    .appSheet(detents: [.large])
                    .toastHost(toastManager: toastManager)

                /// Редактирование тегов трека
            case .trackDetailEdit(let track):
                    TrackDetailContainer(
                        track: track,
                        fileBusyChecker: fileBusyChecker,
                        playbackFileReleaser: playbackFileReleaser,
                        initialMode: .edit
                    )
                    .appSheet(detents: [.large])
                    .toastHost(toastManager: toastManager)

                
                /// Добавить в треклист
            case .addToTrackList(let data):
                AddToTrackListContainer(data: data)
                    .appSheet(detents: [.fraction(0.6), .medium])

                /// Массовое добавление в треклист через тот же UI выбора треклиста.
            case .batchAddToTrackList(let data):
                AddToTrackListContainer(data: data)
                    .appSheet(detents: [.fraction(0.6), .medium])

                /// Выбор треков для нового треклиста
            case .newTrackListSelection(let data):
                NewTrackListSelectionContainer(
                    data: data,
                    renameActionHandler: renameActionHandler,
                    favoriteTrackIdsProvider: favoriteTrackIdsProvider
                )
                    .appSheet(detents: [.large])

                /// Массовое редактирование тегов
            case .batchTagEdit(let data):
                BatchTagEditContainer(
                    flow: $sheetManager.batchTagEditFlow,
                    onClose: {
                        sheetManager.closeActive()
                    },
                    onSave: data.onSave
                )
                .appSheet(detents: [.large])

                /// Массовое переименование файлов
            case .batchFilenameRename(let data):
                BatchFilenameRenameContainer(
                    flow: data.flow,
                    onApply: data.onApply,
                    onClose: {
                        sheetManager.closeActive()
                    }
                )
                .appSheet(detents: [.large])

                /// Создание нового треклиста
            case .createTrackList:
                CreateTrackListContainer()
                    .appSheet(detents: [.fraction(0.55), .medium])

                /// Подробности глобального экспорта.
            case .exportProgress:
                ExportProgressDetailsView()
                    .appSheet(detents: [.medium, .large])
            }
        }
    }
}

// MARK: - Публичный модификатор для подключения SheetHost

extension View {

    /// Подключает централизованный SheetHost к экрану.
    /// Используется один раз в корне приложения.
    func sheetHost(
        sheetManager: SheetManager,
        toastManager: ToastManager,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        fileBusyChecker: any TrackFileBusyChecking,
        playbackFileReleaser: any CurrentPlaybackFileReleasing,
        renameActionHandler: TrackFileRenameActionHandler
    ) -> some View {
        modifier(
            SheetHostModifier(
                sheetManager: sheetManager,
                toastManager: toastManager,
                favoriteTrackIdsProvider: favoriteTrackIdsProvider,
                fileBusyChecker: fileBusyChecker,
                playbackFileReleaser: playbackFileReleaser,
                renameActionHandler: renameActionHandler
            )
        )
    }
}
