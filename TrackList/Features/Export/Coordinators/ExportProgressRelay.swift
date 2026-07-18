//
//  ExportProgressRelay.swift
//  TrackList
//
//  Потокобезопасное схлопывание callback-ов progress.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

/// Потокобезопасно схлопывает callback-и до публикации на MainActor.
/// Relay не хранит задачу и не управляет жизненным циклом операции экспорта.
final class ExportProgressRelay: @unchecked Sendable {

    /// Защищает короткую операцию записи и чтения последнего снимка.
    private let lock = NSLock()

    /// Последний полученный снимок прогресса.
    private var latestProgress: ExportProgress?

    /// Показывает, что для сохранённого в relay снимка уже запланирована
    /// задача доставки, которая ещё не забрала этот снимок.
    /// Пока флаг установлен, новый callback только заменяет latestProgress
    /// и не создаёт дополнительную задачу.
    /// После забора снимка флаг сбрасывается; следующая задача может быть
    /// создана до завершения текущей, но MainActor выполняет их последовательно.
    private var deliveryScheduled = false

    /// Сохраняет снимок и сообщает, нужна ли новая короткая задача доставки.
    func storeAndScheduleIfNeeded(_ progress: ExportProgress) -> Bool {
        lock.lock()
        latestProgress = progress

        guard deliveryScheduled == false else {
            lock.unlock()
            return false
        }

        deliveryScheduled = true
        lock.unlock()
        return true
    }

    /// Забирает снимок для короткой задачи и освобождает возможность
    /// запланировать следующую задачу до публикации этого снимка.
    func takeLatestForDelivery() -> ExportProgress? {
        lock.lock()
        let progress = latestProgress
        latestProgress = nil
        deliveryScheduled = false
        lock.unlock()
        return progress
    }

    /// Забирает последний снимок перед результатом операции и сбрасывает
    /// запланированное состояние, чтобы поздняя пустая задача была безопасной.
    func takeLatestImmediately() -> ExportProgress? {
        lock.lock()
        let progress = latestProgress
        latestProgress = nil
        deliveryScheduled = false
        lock.unlock()
        return progress
    }
}
