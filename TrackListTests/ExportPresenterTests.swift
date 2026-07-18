//
//  ExportPresenterTests.swift
//  TrackList
//
//  Проверки преобразования прогресса экспорта в состояние экрана.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет чистое преобразование внутренних данных экспорта в состояние интерфейса.
final class ExportPresenterTests: XCTestCase {

    /// Проверяет скрытое состояние при отсутствии снимка прогресса.
    func testMakeScreenStateWithoutProgressReturnsHiddenState() {
        let state = ExportPresenter().makeScreenState(
            progress: nil,
            isShowingDetails: false,
            isExportActive: false
        )

        XCTAssertEqual(state.phase, .hidden)
        XCTAssertNil(state.progress)
        XCTAssertFalse(state.isVisible)
        XCTAssertFalse(state.isExportActive)
        XCTAssertFalse(state.canCancel)
        XCTAssertFalse(state.isShowingDetails)
    }

    /// Проверяет сопоставление всех публикуемых состояний экспорта с фазами экрана.
    func testMakeScreenStateMapsExportStatesToScreenPhases() {
        let mappings: [(ExportState, ExportScreenState.Phase, Bool)] = [
            (.idle, .hidden, false),
            (.preparing, .preparing, true),
            (.copying, .copying, true),
            (.completed, .completed, false),
            (.completedWithErrors, .completedWithErrors, false),
            (.cancelled, .cancelled, false),
            (.failed, .failed, false)
        ]

        for (exportState, expectedPhase, expectedCanCancel) in mappings {
            let progress = makeProgress(state: exportState)
            let state = ExportPresenter().makeScreenState(
                progress: progress,
                isShowingDetails: true,
                isExportActive: true
            )

            XCTAssertEqual(state.phase, expectedPhase)
            XCTAssertEqual(state.progress, progress)
            XCTAssertTrue(state.isVisible)
            XCTAssertTrue(state.isExportActive)
            XCTAssertEqual(state.canCancel, expectedCanCancel)
            XCTAssertTrue(state.isShowingDetails)
        }
    }

    /// Создаёт минимальный снимок для проверки отображаемой фазы.
    private func makeProgress(state: ExportState) -> ExportProgress {
        ExportProgress(
            totalFiles: 1,
            destination: ExportDestination(
                folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
            ),
            state: state
        )
    }
}
