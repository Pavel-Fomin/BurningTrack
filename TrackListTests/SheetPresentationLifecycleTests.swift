//
//  SheetPresentationLifecycleTests.swift
//  TrackList
//
//  Проверки жизненного цикла глобальной презентации sheet.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет жизненный цикл SheetManager без запуска SwiftUI, симулятора или устройства.
@MainActor
final class SheetPresentationLifecycleTests: XCTestCase {

    /// Проверяет немедленное открытие сценария, когда другой sheet не отображается и не закрывается.
    func testPresentAtEmptyStateDisplaysRequestedSheet() {
        let manager = SheetManager()

        let route = makeCreateTrackListSheet()
        manager.present(route)

        XCTAssertEqual(manager.activeSheet, route)
    }

    /// Проверяет, что обычное закрытие завершает lifecycle без повторного эффекта от onDismiss.
    func testCloseActiveRecordsDismissedSheetAndCompletesSequence() {
        let manager = SheetManager()

        manager.present(makeCreateTrackListSheet())
        manager.closeActive()

        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        XCTAssertNil(manager.activeSheet)
        XCTAssertNil(manager.highlightedRowID)

        // Повторный callback без ожидающего dismiss не должен менять состояние.
        manager.handleDismiss()
        XCTAssertNil(manager.activeSheet)
    }

    /// Проверяет, что при замене закрытым считается исходный сценарий, а следующий открывается после dismiss.
    func testReplaceActiveRecordsOriginalSheetBeforeOpeningNextSheet() {
        let manager = SheetManager()

        manager.present(makeCreateTrackListSheet())
        manager.replaceActive(with: makeExportDetailsSheet())

        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        XCTAssertExportDetailsSheet(manager.activeSheet)
    }

    /// Проверяет последовательность Track Detail → Move To Folder без подмены закрытого route новым.
    func testDetailReplacementWithMoveToFolderKeepsDetailAsDismissedSheet() {
        let manager = SheetManager()
        let detailTrack = makeTrack()
        let moveTrack = makeTrack()

        manager.present(makeTrackDetailSheet(for: detailTrack))
        manager.replaceActive(with: makeMoveToFolderSheet(for: moveTrack))

        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        XCTAssertMoveToFolderSheet(
            manager.activeSheet,
            hasTrackID: moveTrack.id
        )
    }

    /// Проверяет, что Create TrackList ставит выбор треков в ожидаемый lifecycle, а не назначает его сразу.
    func testCreateTrackListTransitionsToNewTrackListSelectionAfterDismiss() {
        let manager = SheetManager()

        manager.presentCreateTrackList()
        manager.presentNewTrackListSelectionForCreate(name: "Новый треклист")

        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        guard case let .newTrackListSelection(data)? = manager.activeSheet else {
            return XCTFail("После закрытия Create TrackList должен открыться выбор треков")
        }

        XCTAssertEqual(data.mode, .create(trackListName: "Новый треклист"))
    }

    /// Проверяет оба варианта presentCreateTrackList: прямое открытие и замену уже отображаемого сценария.
    func testPresentCreateTrackListUsesSharedPresentationLifecycle() {
        let manager = SheetManager()

        manager.presentCreateTrackList()
        XCTAssertCreateTrackListSheet(manager.activeSheet)

        manager.replaceActive(with: makeExportDetailsSheet())
        manager.handleDismiss()

        manager.presentCreateTrackList()
        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        XCTAssertCreateTrackListSheet(manager.activeSheet)
    }

    /// Проверяет очистку подсветки после окончательного закрытия единственного sheet.
    func testFinalDismissClearsHighlightedRowID() {
        let manager = SheetManager()
        let track = makeTrack()

        manager.present(makeTrackDetailSheet(for: track))
        XCTAssertEqual(manager.highlightedRowID, track.id)

        manager.closeActive()
        manager.handleDismiss()

        XCTAssertNil(manager.highlightedRowID)
    }

    /// Проверяет, что очистка старого sheet не стирает подсветку сценария, открытого после dismiss.
    func testReplacementPreservesHighlightForNextSheet() {
        let manager = SheetManager()
        let detailTrack = makeTrack()
        let moveTrack = makeTrack()

        manager.present(makeTrackDetailSheet(for: detailTrack))
        manager.replaceActive(with: makeMoveToFolderSheet(for: moveTrack))

        // Пока SwiftUI не подтвердил dismiss, подсветка относится к ещё отображаемому detail sheet.
        XCTAssertEqual(manager.highlightedRowID, detailTrack.id)

        manager.handleDismiss()

        XCTAssertEqual(manager.highlightedRowID, moveTrack.id)
    }

    /// Проверяет, что immutable route Batch Tag Edit не мешает открыть следующий sheet после dismiss.
    func testBatchTagEditDismissOpensPendingSheetWithoutSharedFlowReset() {
        let manager = SheetManager()
        manager.presentBatchTagEdit(
            pendingAction: PendingBulkTrackAction(
                action: .editTags,
                trackIDs: [UUID()]
            )
        )
        manager.replaceActive(with: makeCreateTrackListSheet())
        manager.handleDismiss()

        XCTAssertCreateTrackListSheet(manager.activeSheet)
    }

    /// Проверяет правило одного ожидающего сценария: последний запрос во время dismiss заменяет предыдущий.
    func testLatestPresentationRequestReplacesPendingSheetDuringDismiss() {
        let manager = SheetManager()

        manager.present(makeCreateTrackListSheet())
        manager.present(makeExportDetailsSheet())
        manager.presentSaveTrackList()

        XCTAssertNil(manager.activeSheet)

        manager.handleDismiss()

        guard case .saveTrackList? = manager.activeSheet else {
            return XCTFail("Последний pending route должен заменить предыдущий запрос")
        }
    }

    /// Проверяет, что typed Move To Folder dismiss не затрагивает другой активный AppSheet.
    func testMoveToFolderDismissDoesNotCloseAnotherActiveSheet() {
        let manager = SheetManager()
        manager.present(makeCreateTrackListSheet())

        manager.dismissMoveToFolder(UUID())

        XCTAssertCreateTrackListSheet(manager.activeSheet)
    }

    /// Проверяет общую гарантию: completion старого route не закрывает повторно открытый route того же flow.
    func testStaleRouteSpecificDismissKeepsReplacementRoute() {
        let firstTrack = makeTrack()
        let replacementTrack = makeTrack()

        let firstAdd = AddToTrackListSheetData(track: firstTrack)
        let replacementAdd = AddToTrackListSheetData(track: replacementTrack)
        assertStaleDismissKeepsReplacement(
            first: .addToTrackList(firstAdd),
            replacement: .addToTrackList(replacementAdd),
            dismiss: { $0.dismissAddToTrackList(firstAdd.id) }
        )

        let firstSelection = NewTrackListSelectionSheetData(
            mode: .create(trackListName: "First")
        )
        let replacementSelection = NewTrackListSelectionSheetData(
            mode: .create(trackListName: "Second")
        )
        assertStaleDismissKeepsReplacement(
            first: .newTrackListSelection(firstSelection),
            replacement: .newTrackListSelection(replacementSelection),
            dismiss: { $0.dismissNewTrackListSelection(firstSelection.id) }
        )

        let firstRenameFile = RenameTrackFileSheetData(
            trackId: firstTrack.trackId,
            rowId: firstTrack.id,
            currentFileName: firstTrack.fileName
        )
        let replacementRenameFile = RenameTrackFileSheetData(
            trackId: replacementTrack.trackId,
            rowId: replacementTrack.id,
            currentFileName: replacementTrack.fileName
        )
        assertStaleDismissKeepsReplacement(
            first: .renameTrackFile(firstRenameFile),
            replacement: .renameTrackFile(replacementRenameFile),
            dismiss: { $0.dismissRenameTrackFile(firstRenameFile.id) }
        )

        let firstSave = SaveTrackListSheetData()
        let replacementSave = SaveTrackListSheetData()
        assertStaleDismissKeepsReplacement(
            first: .saveTrackList(firstSave),
            replacement: .saveTrackList(replacementSave),
            dismiss: { $0.dismissSaveTrackList(firstSave.id) }
        )

        let firstRenameList = RenameTrackListSheetData(
            trackListId: UUID(),
            currentName: "First"
        )
        let replacementRenameList = RenameTrackListSheetData(
            trackListId: UUID(),
            currentName: "Second"
        )
        assertStaleDismissKeepsReplacement(
            first: .renameTrackList(firstRenameList),
            replacement: .renameTrackList(replacementRenameList),
            dismiss: { $0.dismissRenameTrackList(firstRenameList.id) }
        )

        let firstDetail = TrackDetailSheetData(track: firstTrack, initialMode: .view)
        let replacementDetail = TrackDetailSheetData(track: replacementTrack, initialMode: .edit)
        assertStaleDismissKeepsReplacement(
            first: .trackDetail(firstDetail),
            replacement: .trackDetail(replacementDetail),
            dismiss: { $0.dismissTrackDetail(firstDetail.id) }
        )

        let firstBatchAction = PendingBulkTrackAction(action: .editTags, trackIDs: [UUID()])
        let replacementBatchAction = PendingBulkTrackAction(action: .editTags, trackIDs: [UUID()])
        let firstBatchTag = BatchTagEditSheetData(id: UUID(), pendingAction: firstBatchAction)
        let replacementBatchTag = BatchTagEditSheetData(id: UUID(), pendingAction: replacementBatchAction)
        assertStaleDismissKeepsReplacement(
            first: .batchTagEdit(firstBatchTag),
            replacement: .batchTagEdit(replacementBatchTag),
            dismiss: { $0.dismissBatchTagEdit(firstBatchTag.id) }
        )

        let firstFilenameSeed = BatchFilenameRenameTrackSeed(
            trackId: UUID(),
            folderPath: "/Music/First",
            currentFileName: "First.flac",
            artist: "First",
            title: "Track"
        )
        let replacementFilenameSeed = BatchFilenameRenameTrackSeed(
            trackId: UUID(),
            folderPath: "/Music/Second",
            currentFileName: "Second.flac",
            artist: "Second",
            title: "Track"
        )
        let firstBatchFilename = BatchFilenameRenameSheetData(
            id: UUID(),
            pendingAction: PendingBulkTrackAction(
                action: .renameFiles,
                trackIDs: [firstFilenameSeed.trackId]
            ),
            tracks: [firstFilenameSeed]
        )
        let replacementBatchFilename = BatchFilenameRenameSheetData(
            id: UUID(),
            pendingAction: PendingBulkTrackAction(
                action: .renameFiles,
                trackIDs: [replacementFilenameSeed.trackId]
            ),
            tracks: [replacementFilenameSeed]
        )
        assertStaleDismissKeepsReplacement(
            first: .batchFilenameRename(firstBatchFilename),
            replacement: .batchFilenameRename(replacementBatchFilename),
            dismiss: { $0.dismissBatchFilenameRename(firstBatchFilename.id) }
        )

        let firstMove = MoveToFolderSheetData(track: firstTrack)
        let replacementMove = MoveToFolderSheetData(track: replacementTrack)
        assertStaleDismissKeepsReplacement(
            first: .moveToFolder(firstMove),
            replacement: .moveToFolder(replacementMove),
            dismiss: { $0.dismissMoveToFolder(firstMove.id) }
        )

        let firstCreate = CreateTrackListSheetData()
        let replacementCreate = CreateTrackListSheetData()
        assertStaleDismissKeepsReplacement(
            first: .createTrackList(firstCreate),
            replacement: .createTrackList(replacementCreate),
            dismiss: { $0.dismissCreateTrackList(firstCreate.id) }
        )
    }

    /// Проигрывает последовательность: route A закрыт, route B открыт, поздний completion A приходит снова.
    private func assertStaleDismissKeepsReplacement(
        first: AppSheet,
        replacement: AppSheet,
        dismiss: (SheetManager) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let manager = SheetManager()
        manager.present(first)
        dismiss(manager)
        manager.handleDismiss()
        manager.present(replacement)

        dismiss(manager)

        XCTAssertEqual(manager.activeSheet, replacement, file: file, line: line)
    }

    /// Создаёт минимальную display-модель, достаточную для проверки route и подсветки строки.
    private func makeTrack() -> SheetLifecycleTrack {
        SheetLifecycleTrack(
            id: UUID(),
            trackId: UUID(),
            fileName: "test.flac",
            title: "Test Track",
            artist: "Test Artist",
            duration: 180,
            isAvailable: true
        )
    }

    /// Создаёт move route без зависимости от файловой системы или фонотеки.
    private func makeMoveToFolderSheet(
        for track: SheetLifecycleTrack
    ) -> AppSheet {
        .moveToFolder(
            MoveToFolderSheetData(
                track: track,
                operation: .move
            )
        )
    }

    /// Создаёт независимый route формы создания для lifecycle-проверок.
    private func makeCreateTrackListSheet() -> AppSheet {
        .createTrackList(CreateTrackListSheetData())
    }

    /// Создаёт независимый route карточки, не связывая его ID с доменным ID трека.
    private func makeTrackDetailSheet(
        for track: SheetLifecycleTrack
    ) -> AppSheet {
        .trackDetail(
            TrackDetailSheetData(
                track: track,
                initialMode: .view
            )
        )
    }

    /// Создаёт immutable Export Details route для проверки общего lifecycle.
    private func makeExportDetailsSheet() -> AppSheet {
        .exportProgress(ExportDetailsSheetRoute())
    }

    /// Проверяет Export Details route без сравнения случайной идентичности payload.
    private func XCTAssertExportDetailsSheet(
        _ sheet: AppSheet?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .exportProgress? = sheet else {
            return XCTFail(
                "Ожидался route Export Details",
                file: file,
                line: line
            )
        }
    }

    /// Проверяет тип следующего Create TrackList route без сравнения случайного UUID.
    private func XCTAssertCreateTrackListSheet(
        _ sheet: AppSheet?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .createTrackList? = sheet else {
            return XCTFail(
                "Ожидался route Create TrackList",
                file: file,
                line: line
            )
        }
    }

    /// Проверяет payload открытого Move To Folder без сравнения existential display-моделей.
    private func XCTAssertMoveToFolderSheet(
        _ sheet: AppSheet?,
        hasTrackID expectedTrackID: UUID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .moveToFolder(data)? = sheet else {
            return XCTFail(
                "Ожидался route Move To Folder",
                file: file,
                line: line
            )
        }

        XCTAssertEqual(data.track.id, expectedTrackID, file: file, line: line)
    }
}

/// Минимальная display-модель для тестов не зависит от файлов, базы данных или playback-состояния.
private struct SheetLifecycleTrack: TrackDisplayable {
    let id: UUID
    let trackId: UUID
    let fileName: String
    let title: String?
    let artist: String?
    let duration: Double
    let isAvailable: Bool
}
