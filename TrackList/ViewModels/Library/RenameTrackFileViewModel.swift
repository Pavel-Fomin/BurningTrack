//
//  RenameTrackFileViewModel.swift
//  TrackList
//
//  ViewModel sheet-flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Владеет presentation-state формы и передаёт typed-действия экранному ActionHandler.
@MainActor
final class RenameTrackFileViewModel: ObservableObject {

    /// Готовое состояние, потребляемое SwiftUI-контейнером.
    @Published private(set) var state: RenameTrackFileScreenState

    /// Идентификатор трека, переданный sheet route.
    private let trackId: UUID
    /// Полное исходное имя нужно domain builder-у для сохранения расширения.
    private let currentFileName: String
    /// Формирует presentation-state и сообщения результата операции.
    private let presenter: RenameTrackFilePresenter
    /// Выполняет ручное переименование и typed-маршрутизацию.
    private let actionHandler: RenameTrackFileActionHandler
    /// Не даёт completion закрытого route менять presentation-state.
    private var isSessionActive = true
    /// Удерживает начатую файловую операцию без её отмены при dismiss.
    private var operationTask: Task<Void, Never>?

    init(
        trackId: UUID,
        currentFileName: String,
        initialFileName: String,
        presenter: RenameTrackFilePresenter,
        actionHandler: RenameTrackFileActionHandler
    ) {
        self.trackId = trackId
        self.currentFileName = currentFileName
        self.presenter = presenter
        self.actionHandler = actionHandler
        self.state = presenter.makeState(
            fileName: initialFileName,
            isProcessing: false,
            alert: nil
        )
    }

    /// Обрабатывает только typed-действия UI текущего Rename Track File flow.
    func send(_ action: RenameTrackFileAction) {
        switch action {
        case .fileNameChanged(let fileName):
            state = presenter.makeState(
                fileName: fileName,
                isProcessing: state.isProcessing,
                alert: state.alert
            )

        case .rename:
            rename()

        case .close:
            invalidateSession()
            actionHandler.close()

        case .confirmStopPlayback:
            confirmStopPlayback()

        case .dismissAlert:
            state = presenter.makeState(
                fileName: state.fileName,
                isProcessing: state.isProcessing,
                alert: nil
            )

        case .sheetDisappeared:
            invalidateSession()
        }
    }

    /// Блокирует повторное подтверждение до завершения асинхронной команды.
    private func rename() {
        guard state.isRenameEnabled else { return }

        let fileName = state.fileName
        setProcessing()

        operationTask = Task { [weak self] in
            guard let self else { return }

            let presentation = await actionHandler.rename(
                trackId: trackId,
                currentFileName: currentFileName,
                manualFileName: fileName
            )
            guard isSessionActive else { return }
            apply(presentation)
        }
    }

    /// Повторяет ожидающую команду только для подтверждённого alert остановки плеера.
    private func confirmStopPlayback() {
        guard state.alert == .stopPlayback,
              !state.isProcessing
        else {
            return
        }

        setProcessing()

        operationTask = Task { [weak self] in
            guard let self else { return }

            let presentation = await actionHandler.confirmStopPlayback()
            guard isSessionActive else { return }
            apply(presentation)
        }
    }

    /// Переводит форму в состояние выполнения, сохраняя введённый текст.
    private func setProcessing() {
        state = presenter.makeState(
            fileName: state.fileName,
            isProcessing: true,
            alert: nil
        )
    }

    /// Применяет результат presenter-а без интерпретации domain-ошибок во ViewModel.
    private func apply(_ presentation: RenameTrackFilePresentation) {
        switch presentation {
        case .close:
            state = presenter.makeState(
                fileName: state.fileName,
                isProcessing: false,
                alert: nil
            )

        case .keepOpen(let alert):
            state = presenter.makeState(
                fileName: state.fileName,
                isProcessing: false,
                alert: alert
            )
        }
    }

    /// Завершает только UI-сеанс, оставляя начатую доменную команду согласованно завершиться.
    private func invalidateSession() {
        isSessionActive = false
    }
}
