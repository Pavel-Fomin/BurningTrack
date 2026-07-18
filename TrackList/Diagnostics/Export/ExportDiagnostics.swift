//
//  ExportDiagnostics.swift
//  TrackList
//
//  Агрегированная диагностика жизненного цикла большого экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

#if DEBUG

import Darwin
import Foundation
import UIKit

/// Собирает измерения экспорта только в DEBUG-конфигурации.
final class ExportDiagnostics: @unchecked Sendable {

    /// Единый экземпляр диагностического сборщика.
    static let shared = ExportDiagnostics()

    /// Синхронизирует счётчики callback-ов и фонового состояния.
    private let lock = NSLock()

    /// Очередь редкого агрегированного вывода, не связанная с MainActor.
    private let loggingQueue = DispatchQueue(
        label: "com.burningtrack.export-diagnostics",
        qos: .utility
    )

    /// Состояние текущей диагностической сессии.
    private var state = State()

    /// Таймер вывода одной агрегированной строки в секунду.
    private var loggingTimer: DispatchSourceTimer?

    /// Наблюдатели переходов приложения между active и background.
    private var applicationStateObservers: [NSObjectProtocol] = []

    /// Не позволяет создавать диагностические записи для несуществующей операции.
    private init() {}

    /// Начинает сбор измерений для новой операции.
    @MainActor
    func begin(exportID: UUID, totalFiles: Int) {
        let timer = DispatchSource.makeTimerSource(queue: loggingQueue)
        timer.schedule(
            deadline: .now() + 1,
            repeating: .seconds(1),
            leeway: .milliseconds(100)
        )
        timer.setEventHandler { [weak self] in
            self?.emitLog(force: true)
        }

        lock.lock()
        state = State(
            exportID: exportID,
            totalFiles: totalFiles,
            applicationState: applicationStateName(
                UIApplication.shared.applicationState
            )
        )
        loggingTimer = timer
        lock.unlock()

        installApplicationStateObservers()
        timer.resume()
    }

    /// Отмечает завершение основной операции, но ждёт уже созданные MainActor-задачи.
    @MainActor
    func end() {
        lock.lock()
        state.isEnded = true
        let timer = state.mainActorTaskCount == 0 ? loggingTimer : nil
        if timer != nil {
            loggingTimer = nil
        }
        lock.unlock()

        emitLog(force: true)

        if let timer {
            timer.cancel()
            removeApplicationStateObservers()
        }
    }

    /// Учитывает один реально выполненный callback после чтения блока.
    func recordByteCallback() {
        lock.lock()
        state.byteCallbackCount += 1
        lock.unlock()
    }

    /// Учитывает один переданный снимок прогресса и обновляет его текущие значения.
    func recordProgress(_ progress: ExportProgress) {
        lock.lock()
        state.totalFiles = progress.totalFiles
        state.totalBytes = progress.totalBytes
        state.copiedBytes = progress.copiedBytes
        state.failedFiles = progress.failedFiles.count
        state.progressCallbackCount += 1

        if progress.currentFileName == nil {
            state.currentFileNumber = 0
            state.currentFileSize = 0
        } else {
            state.currentFileSize = progress.currentFileBytes
        }

        state.destinationURL = progress.destination.folderURL
        lock.unlock()
    }

    /// Сохраняет фактический порядковый номер файла из задания экспорта.
    func recordCurrentFile(number: Int, size: Int64) {
        lock.lock()
        state.currentFileNumber = number
        state.currentFileSize = size
        lock.unlock()
    }

    /// Учитывает созданную задачу доставки на MainActor.
    func mainActorTaskCreated() {
        lock.lock()
        state.mainActorTaskCount += 1
        state.createdMainActorTaskCount += 1
        state.peakMainActorTaskCount = max(
            state.peakMainActorTaskCount,
            state.mainActorTaskCount
        )
        lock.unlock()
    }

    /// Учитывает завершение задачи доставки на MainActor.
    func mainActorTaskFinished() {
        lock.lock()
        state.mainActorTaskCount = max(state.mainActorTaskCount - 1, 0)
        let timer = state.isEnded && state.mainActorTaskCount == 0
            ? loggingTimer
            : nil
        if timer != nil {
            loggingTimer = nil
        }
        lock.unlock()

        if let timer {
            emitLog(force: true)
            timer.cancel()
            removeApplicationStateObservers()
        }
    }

    /// Учитывает снимок, который действительно дошёл до опубликованного состояния.
    func recordAppliedProgress() {
        lock.lock()
        state.appliedProgressCount += 1
        lock.unlock()
    }

    /// Учитывает снимок, вытесненный более новым снимком в relay.
    func recordDroppedProgress() {
        lock.lock()
        state.droppedProgressCount += 1
        lock.unlock()
    }

    /// Учитывает открытие пары FileHandle текущего файла.
    func recordFileHandlesOpened() {
        lock.lock()
        state.openFileHandleCount += 2
        state.peakOpenFileHandleCount = max(
            state.peakOpenFileHandleCount,
            state.openFileHandleCount
        )
        lock.unlock()
    }

    /// Учитывает закрытие пары FileHandle текущего файла.
    func recordFileHandlesClosed() {
        lock.lock()
        state.openFileHandleCount = max(state.openFileHandleCount - 2, 0)
        lock.unlock()
    }

    /// Обновляет снимок памяти по таймеру или при завершении операции.
    private func emitLog(force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()
        guard state.exportID != nil else {
            lock.unlock()
            return
        }

        guard force || now - state.lastLogUptime >= 1 else {
            lock.unlock()
            return
        }

        state.lastLogUptime = now
        state.residentMemoryBytes = residentMemoryBytes()
        state.peakResidentMemoryBytes = max(
            state.peakResidentMemoryBytes,
            state.residentMemoryBytes
        )
        state.availableDestinationBytes = availableDestinationBytes(
            at: state.destinationURL
        )
        lock.unlock()
    }

    /// Подписывается на переходы приложения без создания MainActor-задач.
    private func installApplicationStateObservers() {
        let center = NotificationCenter.default
        let notifications: [(Notification.Name, String)] = [
            (UIApplication.didBecomeActiveNotification, "active"),
            (UIApplication.willResignActiveNotification, "inactive"),
            (UIApplication.didEnterBackgroundNotification, "background"),
            (UIApplication.willEnterForegroundNotification, "foreground")
        ]

        let tokens = notifications.map { name, value in
            center.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.setApplicationState(value)
            }
        }

        lock.lock()
        applicationStateObservers = tokens
        lock.unlock()
    }

    /// Сохраняет последнее состояние жизненного цикла приложения.
    private func setApplicationState(_ value: String) {
        lock.lock()
        state.applicationState = value
        lock.unlock()
    }

    /// Освобождает временные наблюдатели после завершения диагностической сессии.
    private func removeApplicationStateObservers() {
        lock.lock()
        let tokens = applicationStateObservers
        applicationStateObservers = []
        lock.unlock()

        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// Возвращает доступный объём на томе назначения, если провайдер его сообщает.
    private func availableDestinationBytes(at url: URL?) -> Int64? {
        guard let url else { return nil }

        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        return values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map { Int64($0) }
    }

    /// Читает resident memory текущего процесса через Mach task info.
    private func residentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }

    /// Преобразует состояние UIApplication в короткую строку для журнала.
    private func applicationStateName(
        _ state: UIApplication.State
    ) -> String {
        switch state {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }

    /// Набор измеряемых значений одной операции.
    private struct State {
        var exportID: UUID?
        var totalFiles: Int
        var totalBytes: Int64
        var currentFileNumber: Int
        var currentFileSize: Int64
        var copiedBytes: Int64
        var byteCallbackCount: Int
        var progressCallbackCount: Int
        var createdMainActorTaskCount: Int
        var mainActorTaskCount: Int
        var peakMainActorTaskCount: Int
        var appliedProgressCount: Int
        var droppedProgressCount: Int
        var residentMemoryBytes: UInt64
        var peakResidentMemoryBytes: UInt64
        var openFileHandleCount: Int
        var peakOpenFileHandleCount: Int
        var applicationState: String
        var destinationURL: URL?
        var availableDestinationBytes: Int64?
        var failedFiles: Int
        var lastLogUptime: TimeInterval
        var isEnded: Bool

        init(
            exportID: UUID? = nil,
            totalFiles: Int = 0,
            applicationState: String = "unknown"
        ) {
            self.exportID = exportID
            self.totalFiles = totalFiles
            self.totalBytes = 0
            self.currentFileNumber = 0
            self.currentFileSize = 0
            self.copiedBytes = 0
            self.byteCallbackCount = 0
            self.progressCallbackCount = 0
            self.createdMainActorTaskCount = 0
            self.mainActorTaskCount = 0
            self.peakMainActorTaskCount = 0
            self.appliedProgressCount = 0
            self.droppedProgressCount = 0
            self.residentMemoryBytes = 0
            self.peakResidentMemoryBytes = 0
            self.openFileHandleCount = 0
            self.peakOpenFileHandleCount = 0
            self.applicationState = applicationState
            self.destinationURL = nil
            self.availableDestinationBytes = nil
            self.failedFiles = 0
            self.lastLogUptime = 0
            self.isEnded = false
        }
    }
}

#endif
