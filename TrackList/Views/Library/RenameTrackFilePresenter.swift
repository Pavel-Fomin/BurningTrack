//
//  RenameTrackFilePresenter.swift
//  TrackList
//
//  Преобразует результаты ручного переименования файла в presentation-state и сообщения.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Результат presentation-слоя, который ViewModel применяет к состоянию экрана.
enum RenameTrackFilePresentation: Equatable {
    /// Операция успешно завершена, поэтому sheet нужно закрыть.
    case close
    /// Sheet остаётся открытым с необязательным системным alert.
    case keepOpen(alert: RenameTrackFileAlert?)
}

/// Формирует состояние формы и интерпретирует результаты существующей команды сохранения.
@MainActor
struct RenameTrackFilePresenter {
    /// Показывает стандартные Toast-сообщения приложения.
    private let toastPresenter: any ToastPresenting

    init(toastPresenter: any ToastPresenting) {
        self.toastPresenter = toastPresenter
    }

    /// Собирает готовое состояние ввода и доступности подтверждения.
    func makeState(
        fileName: String,
        isProcessing: Bool,
        alert: RenameTrackFileAlert?
    ) -> RenameTrackFileScreenState {
        let hasFileName = !fileName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        return RenameTrackFileScreenState(
            fileName: fileName,
            isRenameEnabled: hasFileName && !isProcessing,
            isProcessing: isProcessing,
            alert: alert
        )
    }

    /// Показывает стандартное сообщение успешного сохранения и завершает flow.
    func present(_ result: TrackEditsSavedSuccess) -> RenameTrackFilePresentation {
        AppCommandToastPresenter(
            toastPresenter: toastPresenter
        ).present(result)
        return .close
    }

    /// Преобразует ожидаемую AppError в alert либо существующее Toast-сообщение.
    func present(_ error: AppError) -> RenameTrackFilePresentation {
        switch error {
        case .fileAccessDenied:
            return .keepOpen(alert: .stopPlayback)

        case .fileAlreadyExists:
            return .keepOpen(alert: .fileNameConflict)

        default:
            AppCommandToastPresenter(
                toastPresenter: toastPresenter
            ).present(error)
            return .keepOpen(alert: nil)
        }
    }

    /// Показывает прежнее сообщение, когда предложение нельзя подготовить.
    func presentPreparationFailure() -> RenameTrackFilePresentation {
        toastPresenter.handle(
            .operationFailed(
                message: FileRenamePresentationText.preparationFailedMessage
            )
        )
        return .keepOpen(alert: nil)
    }

    /// Показывает прежнее сообщение для ошибки, не относящейся к AppError.
    func presentUnknownFailure() -> RenameTrackFilePresentation {
        toastPresenter.handle(
            .operationFailed(
                message: FileRenamePresentationText.fileRenameFailedMessage
            )
        )
        return .keepOpen(alert: nil)
    }
}
