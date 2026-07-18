//
//  ExportPresenter.swift
//  TrackList
//
//  Преобразование внутреннего состояния экспорта в состояние экрана.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

/// Формирует единый снимок интерфейса из текущего прогресса операции.
struct ExportPresenter {

    /// Преобразует внутренние данные операции в состояние интерфейса.
    func makeScreenState(
        progress: ExportProgress?,
        isShowingDetails: Bool,
        isExportActive: Bool
    ) -> ExportScreenState {
        let phase = makePhase(for: progress?.state)

        return ExportScreenState(
            phase: phase,
            progress: progress,
            isVisible: progress != nil,
            isExportActive: isExportActive,
            canCancel: isExportActive && canCancel(for: phase),
            isShowingDetails: isShowingDetails
        )
    }

    /// Сопоставляет техническое состояние экспорта с фазой интерфейса.
    private func makePhase(for state: ExportState?) -> ExportScreenState.Phase {
        guard let state else { return .hidden }

        switch state {
        case .idle:
            return .hidden
        case .preparing:
            return .preparing
        case .copying:
            return .copying
        case .completed:
            return .completed
        case .completedWithErrors:
            return .completedWithErrors
        case .cancelled:
            return .cancelled
        case .failed:
            return .failed
        }
    }

    /// Разрешает отмену только в фазах подготовки и фактического копирования.
    private func canCancel(for phase: ExportScreenState.Phase) -> Bool {
        switch phase {
        case .preparing, .copying:
            return true
        case .hidden, .completed, .completedWithErrors, .cancelled, .failed:
            return false
        }
    }
}
