//
//  SaveTrackListActionHandler.swift
//  TrackList
//
//  Выполняет сохранение текущей очереди плеера в новый треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Выполняет доменную операцию и завершает sheet только после успешного сохранения.
@MainActor
final class SaveTrackListActionHandler {
    /// Возвращает актуальную очередь плеера в момент подтверждения формы.
    private let queueProvider: any SaveTrackListQueueProviding
    /// Создаёт треклист из доменных треков очереди.
    private let trackListsService: any SaveTrackListCreating
    /// Показывает пользовательские сообщения flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует закрытие Save TrackList sheet.
    private let router: any SaveTrackListRouting
    /// Неизменяемая идентичность конкретного Save TrackList route.
    private let routeID: UUID

    init(
        queueProvider: any SaveTrackListQueueProviding,
        trackListsService: any SaveTrackListCreating,
        toastPresenter: any ToastPresenting,
        router: any SaveTrackListRouting,
        routeID: UUID = UUID()
    ) {
        self.queueProvider = queueProvider
        self.trackListsService = trackListsService
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
    }

    /// Закрывает sheet без чтения очереди и выполнения доменной команды.
    func cancel() {
        router.dismissSaveTrackList(routeID)
    }

    /// Сохраняет актуальную очередь плеера с нормализованным именем пользователя.
    func submit(name: String) -> SaveTrackListResult {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else { return .failure }

        // Очередь намеренно читается здесь, а не в factory или ViewModel: это сохраняет live-семантику исходного flow.
        let tracks = queueProvider.currentQueueTracks()

        do {
            let created = try trackListsService.createTrackList(
                from: tracks,
                withName: normalizedName
            )
            toastPresenter.handle(.trackListSaved(name: created.name))
            router.dismissSaveTrackList(routeID)
            return .success
        } catch let appError as AppError {
            PersistentLogger.log("SaveTrackListActionHandler: save tracklist failed error=\(appError)")
            toastPresenter.handle(appError)
            return .failure
        } catch {
            PersistentLogger.log("SaveTrackListActionHandler: save tracklist failed error=\(error)")
            toastPresenter.handle(AppError.trackListSaveFailed)
            return .failure
        }
    }
}

/// Результат сохранения для снятия блокировки submit во ViewModel.
enum SaveTrackListResult: Equatable {
    case success
    case failure
}
