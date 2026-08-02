//
//  CurrentPlaybackFileReleasing.swift
//  TrackList
//
//  Контракт освобождения файла текущего воспроизведения.
//
//  Created by Pavel Fomin on 02.08.2026.
//

/// Освобождает файл текущего воспроизведения перед подтверждённой файловой операцией.
/// Контракт не выполняет move, rename или сохранение тегов.
/// Production-provider — PlayerViewModel, чтобы состояние интерфейса оставалось синхронным с PlayerManager.
@MainActor
protocol CurrentPlaybackFileReleasing: AnyObject {

    /// Останавливает воспроизведение и освобождает доступ к текущему файлу.
    func releaseCurrentPlaybackFile()
}
