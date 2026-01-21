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


// MARK: - Перечень шитов

enum AppSheet: Identifiable, Equatable {
    case moveToFolder(MoveToFolderSheetData)
    case trackDetail(any TrackDisplayable)
    case addToTrackList(AddToTrackListSheetData)
    case renameTrackList(RenameTrackListSheetData)
    case saveTrackList(SaveTrackListSheetData)
    

    var id: String {
        switch self {
        case .moveToFolder(let data): return "moveToFolder_\(data.id)"
        case .trackDetail(let track): return "trackDetail_\(track.id)"
        case .addToTrackList(let data): return "addToTrackList_\(data.id)"
        case .renameTrackList(let data): return "renameTrackList_\(data.id)"
        case .saveTrackList(let data): return "saveTrackList_\(data.id)"
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

    /// ID трека для выделения в списках
    @Published var highlightedTrackID: UUID?
    
    /// Счётчик закрытий sheet’ов.
    /// Используется как единая точка UX-commit после dismiss.
    @Published private(set) var dismissCounter: Int = 0

    private init() {}


    // MARK: - ОСНОВНОЙ МЕТОД ПОКАЗА ШИТОВ

    func present(_ sheet: AppSheet) {
        highlightedTrackID = sheet.relatedTrackId

        if activeSheet == nil {
            // Можно открыть сразу
            activeSheet = sheet
        } else {
            // Шит уже на экране → откроем после dismiss
            pendingSheet = sheet
            activeSheet = nil  // закрываем текущий
        }
    }


    // MARK: - ВЫЗЫВАЕТСЯ ИЗ ContentView.onDismiss
  
    func handleDismiss() {
        // Фиксируем факт закрытия sheet — UX-commit
        dismissCounter += 1

        if let next = pendingSheet {
            pendingSheet = nil
            activeSheet = next
        } else {
            highlightedTrackID = nil
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
    
    func presentSaveTrackList() {
        let data = SaveTrackListSheetData()
        present(.saveTrackList(data))
    }
}


// MARK: - Вспомогательная логика извлечения track.id из enum AppSheet

private extension AppSheet {
    var relatedTrackId: UUID? {
        switch self {
        case .moveToFolder(let d): return d.track.id
        case .trackDetail(let t): return t.id
        case .addToTrackList(let data): return data.track.id
        case .renameTrackList: return nil
        case .saveTrackList: return nil
        }
    }
}
