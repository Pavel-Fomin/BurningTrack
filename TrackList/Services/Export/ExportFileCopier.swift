//
//  ExportFileCopier.swift
//  TrackList
//
//  Порционное копирование одного файла с контролем байтового прогресса.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Ошибки низкоуровневого копирования одного файла.
enum ExportFileCopierError: LocalizedError {
    /// Источник не существует или не является обычным файлом.
    case sourceIsNotRegularFile

    /// В папке назначения уже есть объект с нужным именем.
    case destinationAlreadyExists

    /// Не удалось создать временный файл внутри выбранной папки.
    case temporaryFileCreationFailed

    /// Размер источника изменился во время копирования.
    case sourceSizeChanged

    var errorDescription: String? {
        switch self {
        case .sourceIsNotRegularFile:
            return "Исходный объект не является доступным файлом."
        case .destinationAlreadyExists:
            return "Файл с таким именем уже существует в папке назначения."
        case .temporaryFileCreationFailed:
            return "Не удалось создать временный файл в папке назначения."
        case .sourceSizeChanged:
            return "Размер исходного файла изменился во время копирования."
        }
    }
}

/// Копирует один файл кусками, не удерживая весь аудиофайл в памяти.
final class ExportFileCopier {

    /// Размер одного блока чтения и записи.
    private let bufferSize = 1024 * 1024

    /// Выполняет копирование и сообщает количество записанных байтов.
    ///
    /// Все операции выполняются синхронно на вызывающем фоне. Вызывающий
    /// TrackExportService является actor и поэтому этот метод не блокирует
    /// MainActor приложения.
    func copy(
        from sourceURL: URL,
        to destinationURL: URL,
        expectedByteCount: Int64,
        shouldCancel: () -> Bool,
        onBytesCopied: (Int64) -> Void
    ) throws {
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let sourceValues = try sourceURL.resourceValues(
            forKeys: [.isRegularFileKey]
        )
        guard sourceValues.isRegularFile == true else {
            throw ExportFileCopierError.sourceIsNotRegularFile
        }

        guard !hasExistingItem(at: destinationURL) else {
            throw ExportFileCopierError.destinationAlreadyExists
        }

        let partialURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                ".\(destinationURL.lastPathComponent).burningtrack-\(UUID().uuidString).partial",
                isDirectory: false
            )

        var partialFileExists = false

        do {
            try throwIfCancelled(shouldCancel)

            // Создаём частичный файл через URL API. Это важно для iCloud Drive,
            // USB и других файловых провайдеров: сервис не превращает URL
            // назначения в предположительно локальный путь.
            partialFileExists = true
            do {
                try Data().write(
                    to: partialURL,
                    options: [.withoutOverwriting]
                )
            } catch {
                throw ExportFileCopierError.temporaryFileCreationFailed
            }

            let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
            defer {
                try? sourceHandle.close()
            }

            let destinationHandle = try FileHandle(forWritingTo: partialURL)
            #if DEBUG
            ExportDiagnostics.shared.recordFileHandlesOpened()
            #endif
            defer {
                try? destinationHandle.close()
                #if DEBUG
                ExportDiagnostics.shared.recordFileHandlesClosed()
                #endif
            }

            var copiedBytes: Int64 = 0

            while true {
                try throwIfCancelled(shouldCancel)

                var reachedEndOfFile = false
                var copiedBlockByteCount: Int64 = 0

                // Локальный autoreleasepool ограничивает время жизни временных
                // Foundation-объектов чтения и записи одним блоком копирования.
                try autoreleasepool {
                    if let data = try sourceHandle.read(upToCount: bufferSize),
                       data.isEmpty == false {
                        try destinationHandle.write(contentsOf: data)
                        copiedBlockByteCount = Int64(data.count)
                    } else {
                        reachedEndOfFile = true
                    }
                }

                if reachedEndOfFile {
                    break
                }

                copiedBytes += copiedBlockByteCount
                onBytesCopied(copiedBytes)

                try throwIfCancelled(shouldCancel)
            }

            guard copiedBytes == expectedByteCount else {
                throw ExportFileCopierError.sourceSizeChanged
            }

            try destinationHandle.synchronize()
            try destinationHandle.close()
            try sourceHandle.close()

            try throwIfCancelled(shouldCancel)

            // Повторная проверка закрывает редкое окно гонки: другой процесс
            // мог создать файл между начальной проверкой и перемещением.
            guard !hasExistingItem(at: destinationURL) else {
                throw ExportFileCopierError.destinationAlreadyExists
            }

            try FileManager.default.moveItem(at: partialURL, to: destinationURL)
            partialFileExists = false
        } catch {
            if partialFileExists {
                try? FileManager.default.removeItem(at: partialURL)
            }
            throw error
        }
    }

    /// Прерывает текущий цикл сразу после ближайшего завершённого блока.
    private func throwIfCancelled(_ shouldCancel: () -> Bool) throws {
        if shouldCancel() || Task.isCancelled {
            throw CancellationError()
        }
    }

    /// Проверяет наличие любого объекта по URL без преобразования URL в бизнес-путь.
    private func hasExistingItem(at url: URL) -> Bool {
        (try? url.checkResourceIsReachable()) == true
    }
}
