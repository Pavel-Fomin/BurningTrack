//
//  SheetManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.07.2025.
//

import SwiftUI
import Foundation


// MARK: - Данные для MoveToFolderSheet

struct MoveToFolderSheetData: Identifiable, Equatable {
    let id = UUID()
    let track: any TrackDisplayable

    static func == (lhs: MoveToFolderSheetData, rhs: MoveToFolderSheetData) -> Bool { lhs.id == rhs.id
    }
}

// MARK: - Данные для RenameTrackListSheet

struct RenameTrackListSheetData: Identifiable, Equatable {
    let id = UUID()
    let trackListId: UUID
    let currentName: String

    static func == (lhs: RenameTrackListSheetData, rhs: RenameTrackListSheetData) -> Bool { lhs.id == rhs.id
    }
}

// MARK: - Данные для RenameTrackFileSheet

struct RenameTrackFileSheetData: Identifiable, Equatable {
    let id = UUID()
    let trackId: UUID
    let rowId: UUID
    let currentFileName: String

    static func == (
        lhs: RenameTrackFileSheetData,
        rhs: RenameTrackFileSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Данные для SaveTrackListSheet

struct SaveTrackListSheetData: Identifiable, Equatable {
    let id = UUID()

    static func == (
        lhs: SaveTrackListSheetData,
        rhs: SaveTrackListSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Данные для NewTrackListSelectionSheet

enum NewTrackListSelectionMode: Equatable {
    case create(trackListName: String)
    case append(trackListId: UUID)
}

struct NewTrackListSelectionSheetData: Identifiable, Equatable {
    let id = UUID()
    let mode: NewTrackListSelectionMode
}

// MARK: - Данные для AddToTrackListSheet

struct AddToTrackListSheetData: Identifiable, Equatable {
    let id = UUID()
    let track: LibraryTrack
    let sourceTrackListId: UUID?   // ← ВАЖНО

    static func == (
        lhs: AddToTrackListSheetData,
        rhs: AddToTrackListSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Данные для BatchTagEditSheet

/// Данные для показа sheet массового редактирования тегов.
struct BatchTagEditSheetData: Identifiable, Equatable {
    /// Идентификатор sheet.
    let id: UUID
}


// MARK: - Перечень шитов

enum AppSheet: Identifiable, Equatable {
    case moveToFolder(MoveToFolderSheetData)
    case trackDetail(any TrackDisplayable)
    case addToTrackList(AddToTrackListSheetData)
    case renameTrackList(RenameTrackListSheetData)
    case renameTrackFile(RenameTrackFileSheetData)
    case saveTrackList(SaveTrackListSheetData)
    case newTrackListSelection(NewTrackListSelectionSheetData)
    case batchTagEdit(BatchTagEditSheetData)
    case createTrackList
    

    var id: String {
        switch self {
        case .moveToFolder(let data): return "moveToFolder_\(data.id)"
        case .trackDetail(let track): return "trackDetail_\(track.id)"
        case .addToTrackList(let data): return "addToTrackList_\(data.id)"
        case .renameTrackList(let data): return "renameTrackList_\(data.id)"
        case .renameTrackFile(let data): return "renameTrackFile_\(data.id)"
        case .saveTrackList(let data): return "saveTrackList_\(data.id)"
        case .newTrackListSelection(let data): return "newTrackListSelection_\(data.id)"
        case .batchTagEdit(let data): return "batchTagEdit_\(data.id)"
        case .createTrackList: return "createTrackList"
        }
    }

    static func == (lhs: AppSheet, rhs: AppSheet) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SheetManager

@MainActor
final class SheetManager: ObservableObject {

    static let shared = SheetManager()

    /// Текущий отображаемый шит
    @Published var activeSheet: AppSheet?   /// Текущий отображаемый шит

    /// Следующий шит, который должен открыться после dismiss текущего
    private var pendingSheet: AppSheet?

    /// Последний показанный sheet для корректной очистки состояния после dismiss.
    private var lastActiveSheet: AppSheet?

    /// ID строки для выделения в списках
    @Published var highlightedRowID: UUID?
    
    /// Счётчик закрытий sheet’ов.
    /// Используется как единая точка UX-commit после dismiss.
    @Published private(set) var dismissCounter: Int = 0

    /// Flow массового редактирования тегов.
    @Published var batchTagEditFlow = BatchTagEditFlow(
        pendingAction: nil,
        phase: .editing,
        tracks: [],
        fields: [],
        artwork: BatchTagArtworkEditState(
            action: .keep,
            newArtworkData: nil,
            summary: .none,
            previewSummary: BatchTagArtworkPreviewSummary(
                selectedCount: 0,
                artworkCount: 0,
                missingArtworkCount: 0
            ),
            previewItems: [],
            selectedTarget: nil
        )
    )

    private init() {}


    // MARK: - ОСНОВНОЙ МЕТОД ПОКАЗА ШИТОВ

    func present(_ sheet: AppSheet) {
        highlightedRowID = sheet.relatedRowId

        if activeSheet == nil {
            // Можно открыть сразу
            activeSheet = sheet
            lastActiveSheet = sheet
        } else {
            // Шит уже на экране → откроем после dismiss
            pendingSheet = sheet
            activeSheet = nil  // закрываем текущий
        }
    }


    // MARK: - ВЫЗЫВАЕТСЯ ИЗ ContentView.onDismiss
  
    func handleDismiss() {
        let dismissedSheet = activeSheet ?? lastActiveSheet

        // Фиксируем факт закрытия sheet — UX-commit
        dismissCounter += 1

        resetTransientStateIfNeeded(for: dismissedSheet)

        if let next = pendingSheet {
            pendingSheet = nil
            activeSheet = next
            lastActiveSheet = next
        } else {
            lastActiveSheet = nil
            highlightedRowID = nil
        }
    }
    
    
    // MARK: - Хелперы для вызова конкретных шитов

    func presentMoveToFolder(for track: any TrackDisplayable) {
        let data = MoveToFolderSheetData(track: track)
        present(.moveToFolder(data))
    }

    func presentTrackDetail(_ track: any TrackDisplayable) {
        present(.trackDetail(track))
    }

    func presentAddToTrackList(
        for track: LibraryTrack,
        sourceTrackListId: UUID? = nil
    ) {
        let data = AddToTrackListSheetData(
            track: track,
            sourceTrackListId: sourceTrackListId
        )
        present(.addToTrackList(data))
    }

    func closeActive() {
        activeSheet = nil
    }
    
    func presentRenameTrackList(
        trackListId: UUID,
        currentName: String
    ) {
        let data = RenameTrackListSheetData(
            trackListId: trackListId,
            currentName: currentName
        )
        present(.renameTrackList(data))
    }

    func presentRenameTrackFile(
        trackId: UUID,
        rowId: UUID,
        currentFileName: String
    ) {
        let data = RenameTrackFileSheetData(
            trackId: trackId,
            rowId: rowId,
            currentFileName: currentFileName
        )
        present(.renameTrackFile(data))
    }
    
    func presentSaveTrackList() {
        let data = SaveTrackListSheetData()
        present(.saveTrackList(data))
    }

    func presentNewTrackListSelectionForCreate(name: String) {
        let data = NewTrackListSelectionSheetData(
            mode: .create(trackListName: name)
        )
        present(.newTrackListSelection(data))
    }

    func presentNewTrackListSelectionForAppend(trackListId: UUID) {
        let data = NewTrackListSelectionSheetData(
            mode: .append(trackListId: trackListId)
        )
        present(.newTrackListSelection(data))
    }

    func presentCreateTrackList() {
        activeSheet = .createTrackList
        lastActiveSheet = .createTrackList
    }

    /// Показывает sheet массового редактирования тегов.
    func presentBatchTagEdit(flow: BatchTagEditFlow) {
        batchTagEditFlow = flow
        present(.batchTagEdit(BatchTagEditSheetData(id: UUID())))
    }

    /// Сбрасывает временные состояния sheet после закрытия.
    private func resetTransientStateIfNeeded(for sheet: AppSheet?) {
        guard case .batchTagEdit = sheet else { return }

        resetBatchTagEditFlow()
    }

    /// Сбрасывает flow массового редактирования тегов.
    private func resetBatchTagEditFlow() {
        batchTagEditFlow = BatchTagEditFlow(
            pendingAction: nil,
            phase: .editing,
            tracks: [],
            fields: [],
            artwork: BatchTagArtworkEditState(
                action: .keep,
                newArtworkData: nil,
                summary: .none,
                previewSummary: BatchTagArtworkPreviewSummary(
                    selectedCount: 0,
                    artworkCount: 0,
                    missingArtworkCount: 0
                ),
                previewItems: [],
                selectedTarget: nil
            )
        )
    }
}


// MARK: - Вспомогательная логика извлечения id строки из enum AppSheet

private extension AppSheet {
    var relatedRowId: UUID? {
        switch self {
        case .moveToFolder(let d): return d.track.id
        case .trackDetail(let t): return t.id
        case .addToTrackList(let data): return data.track.id
        case .renameTrackList: return nil
        case .renameTrackFile(let data): return data.rowId
        case .saveTrackList: return nil
        case .newTrackListSelection: return nil
        case .batchTagEdit: return nil
        case .createTrackList: return nil
        }
    }
}
