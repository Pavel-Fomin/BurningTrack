//
//  FavoriteTrackActionHandler.swift
//  TrackList
//
//  Передаёт переключение «Избранного» в общий доменный сервис.
//
//  Created by Pavel Fomin on 01.08.2026.
//

import Foundation

/// Явно отделяет подтверждённое изменение избранного от terminal failure без ложного UI-success.
enum FavoriteTrackActionOutcome {
    case confirmed(FavoritesMutationResult)
    case failed
}

/// Выполняет переключение «Избранного» через единственный доменный сервис без оптимистического UI-состояния.
@MainActor
struct FavoriteTrackActionHandler {

    /// Общий сервис хранит состояние в существующем системном треклисте и публикует подтверждённое изменение.
    private let favoritesService: any FavoritesServicing
    /// Показывает ошибку только из уже подготовленного Composition Root presentation-flow.
    private let toastPresenter: (any ToastPresenting)?

    /// Создаёт обработчик с явно переданными production- или тестовыми зависимостями.
    init(
        favoritesService: any FavoritesServicing,
        toastPresenter: (any ToastPresenting)? = nil
    ) {
        self.favoritesService = favoritesService
        self.toastPresenter = toastPresenter
    }

    /// Передаёт переключение в доменный сервис и возвращает явный terminal outcome записи.
    @discardableResult
    func toggle(_ track: FavoriteTrackInput) -> FavoriteTrackActionOutcome {
        do {
            return .confirmed(try favoritesService.toggle(track))
        } catch let appError as AppError {
            toastPresenter?.handle(appError)
            PersistentLogger.log(
                "FavoriteTrackActionHandler: подтверждение избранного не получено trackId=\(track.trackId) error=\(appError)"
            )
            return .failed
        } catch {
            toastPresenter?.handle(.unknown)
            // До успешной записи ViewModel не меняют published-состояние самостоятельно.
            PersistentLogger.log(
                "FavoriteTrackActionHandler: ошибка переключения избранного trackId=\(track.trackId) error=\(error)"
            )
            return .failed
        }
    }
}
