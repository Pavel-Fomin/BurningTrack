//
//  ExportDestinationResolver.swift
//  TrackList
//
//  Выбор папки назначения через системный UIDocumentPicker.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

/// Ошибки, возникающие до запуска копирования при выборе папки.
enum ExportDestinationResolverError: LocalizedError {
    /// Другой системный picker уже ожидает выбора пользователя.
    case pickerAlreadyPresented

    /// Системный picker вернул объект, который не является папкой.
    case selectedItemIsNotDirectory

    var errorDescription: String? {
        switch self {
        case .pickerAlreadyPresented:
            return "Выбор папки экспорта уже выполняется."
        case .selectedItemIsNotDirectory:
            return "Выбранный объект не является папкой."
        }
    }
}

/// Контракт системного выбора папки, отделённый от копирования файлов.
@MainActor
protocol ExportDestinationResolving: AnyObject {
    /// Показывает системный выбор папки и возвращает выбранное назначение.
    func resolveDestination(
        presenter: UIViewController
    ) async throws -> ExportDestination

    /// Отменяет активный выбор папки, если он сейчас отображается.
    func cancelCurrentResolution()
}

/// Адаптер UIDocumentPicker, который отвечает только за выбор папки.
@MainActor
final class ExportDestinationResolver: NSObject, ExportDestinationResolving, UIDocumentPickerDelegate {

    /// Продолжение текущего асинхронного выбора папки.
    private var resolutionContinuation: CheckedContinuation<ExportDestination, Error>?

    /// Ссылка на активный picker для корректного закрытия при отмене операции.
    private weak var activePicker: UIDocumentPickerViewController?

    /// Показывает пользователю системный picker только для выбора папки.
    func resolveDestination(
        presenter: UIViewController
    ) async throws -> ExportDestination {
        guard resolutionContinuation == nil else {
            throw ExportDestinationResolverError.pickerAlreadyPresented
        }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.folder],
            asCopy: false
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        activePicker = picker

        return try await withCheckedThrowingContinuation { continuation in
            resolutionContinuation = continuation
            presenter.present(picker, animated: true)
        }
    }

    /// Отменяет picker и завершает его continuation без запуска экспорта.
    func cancelCurrentResolution() {
        guard let continuation = resolutionContinuation else { return }

        resolutionContinuation = nil
        activePicker?.dismiss(animated: true)
        activePicker = nil
        continuation.resume(throwing: CancellationError())
    }

    /// Получает URL выбранной папки и передаёт его сервису копирования.
    ///
    /// Security-scoped доступ здесь не удерживается: его жизненный цикл должен
    /// совпадать со всей операцией копирования и поэтому управляется сервисом.
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else {
            finish(with: ExportDestinationResolverError.selectedItemIsNotDirectory)
            return
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                finish(with: ExportDestinationResolverError.selectedItemIsNotDirectory)
                return
            }
        } catch {
            finish(with: error)
            return
        }

        finish(with: ExportDestination(folderURL: url))
    }

    /// Завершает выбор папки после отказа пользователя от системного picker.
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard let continuation = resolutionContinuation else { return }

        resolutionContinuation = nil
        activePicker = nil
        continuation.resume(throwing: CancellationError())
    }

    /// Возвращает ошибку ожидающему вызывающему коду и освобождает picker.
    private func finish(with error: Error) {
        guard let continuation = resolutionContinuation else { return }

        resolutionContinuation = nil
        activePicker = nil
        continuation.resume(throwing: error)
    }

    /// Возвращает выбранную папку ожидающему вызывающему коду.
    private func finish(with destination: ExportDestination) {
        guard let continuation = resolutionContinuation else { return }

        resolutionContinuation = nil
        activePicker = nil
        continuation.resume(returning: destination)
    }
}
