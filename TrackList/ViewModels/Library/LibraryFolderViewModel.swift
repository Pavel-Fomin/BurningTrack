//
//  LibraryFolderViewModel.swift
//  TrackList
//
//  ViewModel для папки фонотеки
//
//  Created by Pavel Fomin on 08.08.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LibraryFolderViewModel: ObservableObject {
    // MARK: - Output

    @Published private(set) var screenState: LibraryFolderScreenState

    // MARK: - Dependencies

    private let actionHandler: LibraryFolderActionHandler
    /// Собирает готовое состояние папки, не перенося логику отображения во View.
    private let stateBuilder: LibraryFolderStateBuilder
    /// Получает SQLite-статистику без зависимости от экрана и менеджеров фонотеки.
    private let summaryProvider: any TrackCollectionSummaryProviding
    /// Передаёт только события, влияющие на сохранённое содержимое фонотеки.
    private let eventProvider: any LibraryTrackEventProvider
    /// Не даёт устаревшему запросу применить результат после следующего обновления.
    private var summaryTask: Task<Void, Never>?
    /// Удерживает подписки на события в течение жизни ViewModel.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        folder: LibraryFolder,
        stateBuilder: LibraryFolderStateBuilder,
        actionHandler: LibraryFolderActionHandler,
        summaryProvider: any TrackCollectionSummaryProviding,
        eventProvider: any LibraryTrackEventProvider
    ) {
        self.stateBuilder = stateBuilder
        self.screenState = stateBuilder.build(folder: folder)
        self.actionHandler = actionHandler
        self.summaryProvider = summaryProvider
        self.eventProvider = eventProvider

        bindSummaryEvents()
        reloadSummary()
    }

    deinit {
        // Незавершённый SQLite-запрос больше не нужен после закрытия экрана папки.
        summaryTask?.cancel()
    }

    // MARK: - Actions

    func handle(_ action: LibraryFolderAction) {
        actionHandler.handle(action)
    }

    // MARK: - Summary

    /// Подписывается на завершение синхронизации, перемещение и изменение сохранённой длительности трека.
    private func bindSummaryEvents() {
        eventProvider.libraryDataDidChange
            .sink { [weak self] _ in
                self?.reloadSummary()
            }
            .store(in: &cancellables)

        eventProvider.trackDidUpdate
            .filter { event in
                event.reason == .fileMoved || event.changedFields.contains(.duration)
            }
            .sink { [weak self] _ in
                self?.reloadSummary()
            }
            .store(in: &cancellables)

        eventProvider.trackBatchDidUpdate
            .filter { events in
                events.contains { event in
                    event.reason == .fileMoved || event.changedFields.contains(.duration)
                }
            }
            .sink { [weak self] _ in
                self?.reloadSummary()
            }
            .store(in: &cancellables)
    }

    /// Загружает статистику отдельно от списка и применяет только актуальный результат текущей папки.
    private func reloadSummary() {
        let folderId = screenState.folder.id
        summaryTask?.cancel()

        let summaryProvider = summaryProvider
        summaryTask = Task { [weak self] in
            do {
                let summary = try await summaryProvider.summaryForFolder(folderId: folderId)
                guard Task.isCancelled == false,
                      let self,
                      self.screenState.folder.id == folderId else {
                    return
                }

                self.screenState = self.stateBuilder.build(
                    folder: self.screenState.folder,
                    summary: summary
                )
            } catch is CancellationError {
                // Отмена ожидаема при новом событии или закрытии экрана.
            } catch {
                guard Task.isCancelled == false,
                      let self,
                      self.screenState.folder.id == folderId else {
                    return
                }

                // Ошибка статистики не должна нарушать работу папки и не требует отдельного toast.
                PersistentLogger.log("LibraryFolderViewModel: summary loading failed folderId=\(folderId) error=\(error)")
                self.screenState = self.stateBuilder.build(
                    folder: self.screenState.folder,
                    summary: nil
                )
            }
        }
    }
}
