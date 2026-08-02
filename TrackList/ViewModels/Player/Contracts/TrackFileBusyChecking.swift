//
//  TrackFileBusyChecking.swift
//  TrackList
//
//  Контракт проверки занятости файла трека плеером.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Проверяет, удерживает ли плеер доступ к файлу указанного трека.
/// Контракт намеренно не предоставляет playback-команды, UI-состояние или AVPlayer.
/// Production-provider — PlayerManager; Domain получает capability вместо конкретного manager-типа.
@MainActor
protocol TrackFileBusyChecking: AnyObject {

    /// Возвращает признак использования файла трека активным плеером.
    func isTrackFileBusy(trackId: UUID) -> Bool
}

extension PlayerManager: TrackFileBusyChecking {

    /// Адаптирует внутреннюю проверку менеджера к нейтральному контракту файловых операций.
    func isTrackFileBusy(trackId: UUID) -> Bool {
        isBusy(trackId)
    }
}
