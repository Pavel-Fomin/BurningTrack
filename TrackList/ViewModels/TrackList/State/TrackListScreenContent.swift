//
//  TrackListScreenContent.swift
//  TrackList
//
//  Состояние загрузки detail-экрана одного треклиста.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Разделяет начальную загрузку, отсутствие треклиста и готовое состояние без дублирования строк ScreenState.
enum TrackListScreenContent {
    /// Первое чтение detail-снимка ещё не завершилось.
    case loading
    /// Готовое presentation-состояние с треками или корректно пустым списком.
    case loaded(TrackListScreenState)
    /// Маршрут больше не существует в постоянном хранилище.
    case notFound
    /// Первое чтение завершилось ошибкой; пользователь может повторить попытку.
    case failed
}
