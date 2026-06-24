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

    @ObservedObject private var sheetManager = SheetManager.shared

    /// Единый PlayerManager передаётся в rename-flow, чтобы файловые операции
    /// использовали тот же playback backend, что и активный плеер.
    let playerManager: PlayerManager

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
                    playerManager: playerManager
                )
                .appSheet(detents: [.fraction(0.45), .medium])
                .toastHost()
                
                /// Перемещение трека
            case .moveToFolder(let data):
                MoveToFolderContainer(
                    data: data,
                    playerManager: playerManager
                )
                .appSheet(detents: [.fraction(0.6), .medium])
                
                /// О треке
            case .trackDetail(let track):
                    TrackDetailContainer(
                        track: track,
                        playerManager: playerManager
                    )
                    .appSheet(detents: [.large])
                    .toastHost()

                /// Редактирование тегов трека
            case .trackDetailEdit(let track):
                    TrackDetailContainer(
                        track: track,
                        playerManager: playerManager,
                        initialMode: .edit
                    )
                    .appSheet(detents: [.large])
                    .toastHost()

                
                /// Добавить в треклист
            case .addToTrackList(let data):
                AddToTrackListContainer(data: data)
                    .appSheet(detents: [.fraction(0.6), .medium])

                /// Выбор треков для нового треклиста
            case .newTrackListSelection(let data):
                NewTrackListSelectionContainer(
                    data: data,
                    renameActionHandler: TrackFileRenameActionHandler(
                        playerManager: playerManager,
                        sheetManager: SheetManager.shared,
                        commandExecutor: AppCommandExecutor.shared,
                        toastManager: ToastManager.shared,
                        proposalBuilder: FileRenameProposalBuilder()
                    )
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
                    playerManager: data.playerManager,
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
            }
        }
    }
}

// MARK: - Публичный модификатор для подключения SheetHost

extension View {

    /// Подключает централизованный SheetHost к экрану.
    /// Используется один раз в корне приложения.
    func sheetHost(playerManager: PlayerManager) -> some View {
        modifier(SheetHostModifier(playerManager: playerManager))
    }
}
