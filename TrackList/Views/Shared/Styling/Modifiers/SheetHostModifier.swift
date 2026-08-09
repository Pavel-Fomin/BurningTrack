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
    /// Проверяет занятость файла без передачи Sheet-сценариям PlayerManager.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Готовая factory feature-flow выбора папки и файловой операции.
    let moveToFolderFeatureFactory: MoveToFolderFeatureFactory
    /// Готовая factory связанного flow создания и выбора треклиста.
    let createTrackListFlowFactory: CreateTrackListFlowFactory
    /// Готовая factory feature-flow переименования треклиста.
    let renameTrackListFeatureFactory: RenameTrackListFeatureFactory
    /// Готовая factory feature-flow добавления треков в треклист.
    let addToTrackListFeatureFactory: AddToTrackListFeatureFactory
    /// Готовая factory feature-flow сохранения очереди плеера в треклист.
    let saveTrackListFeatureFactory: SaveTrackListFeatureFactory
    /// Готовая factory feature-flow ручного переименования файла трека.
    let renameTrackFileFeatureFactory: RenameTrackFileFeatureFactory
    /// Готовая factory feature-flow просмотра и редактирования одного трека.
    let trackDetailFeatureFactory: TrackDetailFeatureFactory
    /// Готовая factory feature-local массового редактирования тегов.
    let batchTagEditFeatureFactory: BatchTagEditFeatureFactory
    /// Готовая factory feature-local массового переименования файлов.
    let batchFilenameRenameFeatureFactory: BatchFilenameRenameFeatureFactory

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
            case .saveTrackList(let data):
                saveTrackListFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.fraction(0.45), .medium])
                
                /// Переименование треклиста
            case .renameTrackList(let data):
                renameTrackListFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.fraction(0.45), .medium])

                /// Ручное переименование файла трека
            case .renameTrackFile(let data):
                renameTrackFileFeatureFactory.makeView(data: data)
                .appSheet(detents: [.fraction(0.45), .medium])
                
                /// Перемещение трека
            case .moveToFolder(let data):
                moveToFolderFeatureFactory.makeView(data: data)
                .appSheet(detents: [.fraction(0.6), .medium])
                
                /// О треке
            case .trackDetail(let data):
                    trackDetailFeatureFactory.makeView(
                        data: data
                    )
                    .appSheet(detents: [.large])

                
                /// Добавить в треклист
            case .addToTrackList(let data):
                addToTrackListFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.fraction(0.6), .medium])

                /// Массовое добавление в треклист через тот же UI выбора треклиста.
            case .batchAddToTrackList(let data):
                addToTrackListFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.fraction(0.6), .medium])

                /// Выбор треков для нового треклиста
            case .newTrackListSelection(let data):
                createTrackListFlowFactory.makeSelectionView(data: data)
                    .appSheet(detents: [.large])

                /// Массовое редактирование тегов
            case .batchTagEdit(let data):
                batchTagEditFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.large])

                /// Массовое переименование файлов
            case .batchFilenameRename(let data):
                batchFilenameRenameFeatureFactory.makeView(data: data)
                    .appSheet(detents: [.large])

                /// Создание нового треклиста
            case .createTrackList(let data):
                createTrackListFlowFactory.makeCreateTrackListView(data: data)
                    .appSheet(detents: [.fraction(0.55), .medium])

                /// Подробности глобального экспорта.
            case .exportProgress(let route):
                ExportProgressDetailsView(route: route)
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
        fileBusyChecker: any TrackFileBusyChecking,
        moveToFolderFeatureFactory: MoveToFolderFeatureFactory,
        createTrackListFlowFactory: CreateTrackListFlowFactory,
        renameTrackListFeatureFactory: RenameTrackListFeatureFactory,
        addToTrackListFeatureFactory: AddToTrackListFeatureFactory,
        saveTrackListFeatureFactory: SaveTrackListFeatureFactory,
        renameTrackFileFeatureFactory: RenameTrackFileFeatureFactory,
        trackDetailFeatureFactory: TrackDetailFeatureFactory,
        batchTagEditFeatureFactory: BatchTagEditFeatureFactory,
        batchFilenameRenameFeatureFactory: BatchFilenameRenameFeatureFactory
    ) -> some View {
        modifier(
            SheetHostModifier(
                sheetManager: sheetManager,
                fileBusyChecker: fileBusyChecker,
                moveToFolderFeatureFactory: moveToFolderFeatureFactory,
                createTrackListFlowFactory: createTrackListFlowFactory,
                renameTrackListFeatureFactory: renameTrackListFeatureFactory,
                addToTrackListFeatureFactory: addToTrackListFeatureFactory,
                saveTrackListFeatureFactory: saveTrackListFeatureFactory,
                renameTrackFileFeatureFactory: renameTrackFileFeatureFactory,
                trackDetailFeatureFactory: trackDetailFeatureFactory,
                batchTagEditFeatureFactory: batchTagEditFeatureFactory,
                batchFilenameRenameFeatureFactory: batchFilenameRenameFeatureFactory
            )
        )
    }
}
