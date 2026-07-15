//
//  SheetManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.07.2025.
//

import SwiftUI
import Foundation


// MARK: - Данные для MoveToFolderSheet

/// Режим файловой операции после выбора папки назначения.
enum MoveToFolderOperation: Equatable {
    /// Обычное перемещение файлового трека фонотеки.
    case move
    /// Копирование купленного iTunes-трека через выбранную папку назначения.
    case copyPurchasedITunes
}

struct MoveToFolderSheetData: Identifiable, Equatable {
    let id = UUID()
    let track: any TrackDisplayable
    let operation: MoveToFolderOperation

    /// Создаёт payload выбора папки для файлового действия.
    init(
        track: any TrackDisplayable,
        operation: MoveToFolderOperation = .move
    ) {
        self.track = track
        self.operation = operation
    }

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
    let tracks: [any TrackDisplayable]
    let libraryBatchTracks: [LibraryTrack]?
    let sourceTrackListId: UUID?   // ← ВАЖНО

    /// Создаёт payload одиночного добавления без изменения существующего swipe-flow.
    init(
        track: any TrackDisplayable,
        sourceTrackListId: UUID? = nil
    ) {
        self.tracks = [track]
        self.libraryBatchTracks = nil
        self.sourceTrackListId = sourceTrackListId
    }

    /// Создаёт payload массового добавления треков фонотеки.
    init(
        libraryBatchTracks: [LibraryTrack],
        sourceTrackListId: UUID? = nil
    ) {
        self.tracks = libraryBatchTracks.map { $0 as any TrackDisplayable }
        self.libraryBatchTracks = libraryBatchTracks
        self.sourceTrackListId = sourceTrackListId
    }

    /// Идентификаторы треков в порядке выбора.
    var trackIds: [UUID] {
        tracks.map { $0.trackId }
    }

    /// Первый трек нужен только для совместимости с подсветкой одиночного row-flow.
    var firstTrack: (any TrackDisplayable)? {
        tracks.first
    }

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

    /// Сохранение массовых изменений тегов.
    let onSave: () async -> Void

    static func == (
        lhs: BatchTagEditSheetData,
        rhs: BatchTagEditSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Данные для BatchFilenameRenameSheet

/// Данные для показа sheet массового переименования файлов.
struct BatchFilenameRenameSheetData: Identifiable, Equatable {
    /// Идентификатор sheet.
    let id = UUID()

    /// Flow массового переименования файлов.
    let flow: BatchFilenameRenameFlow

    /// Менеджер плеера для проверки занятых файлов при применении команды.
    let playerManager: PlayerManager

    /// Применение подготовленного плана переименования.
    let onApply: () async -> Void

    static func == (
        lhs: BatchFilenameRenameSheetData,
        rhs: BatchFilenameRenameSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Перечень шитов

enum AppSheetKind: Equatable {
    case moveToFolder
    case trackDetail
    case addToTrackList
    case renameTrackList
    case renameTrackFile
    case saveTrackList
    case newTrackListSelection
    case batchTagEdit
    case batchFilenameRename
    case batchAddToTrackList
    case createTrackList
    case exportProgress
}

enum AppSheet: Identifiable, Equatable {
    case moveToFolder(MoveToFolderSheetData)
    case trackDetail(any TrackDisplayable)
    case trackDetailEdit(any TrackDisplayable)
    case addToTrackList(AddToTrackListSheetData)
    case renameTrackList(RenameTrackListSheetData)
    case renameTrackFile(RenameTrackFileSheetData)
    case saveTrackList(SaveTrackListSheetData)
    case newTrackListSelection(NewTrackListSelectionSheetData)
    case batchTagEdit(BatchTagEditSheetData)
    case batchFilenameRename(BatchFilenameRenameSheetData)
    case batchAddToTrackList(AddToTrackListSheetData)
    case createTrackList
    case exportProgress
    

    var id: String {
        switch self {
        case .moveToFolder(let data): return "moveToFolder_\(data.id)"
        case .trackDetail(let track): return "trackDetail_\(track.id)"
        case .trackDetailEdit(let track): return "trackDetailEdit_\(track.id)"
        case .addToTrackList(let data): return "addToTrackList_\(data.id)"
        case .renameTrackList(let data): return "renameTrackList_\(data.id)"
        case .renameTrackFile(let data): return "renameTrackFile_\(data.id)"
        case .saveTrackList(let data): return "saveTrackList_\(data.id)"
        case .newTrackListSelection(let data): return "newTrackListSelection_\(data.id)"
        case .batchTagEdit(let data): return "batchTagEdit_\(data.id)"
        case .batchFilenameRename(let data): return "batchFilenameRename_\(data.id)"
        case .batchAddToTrackList(let data): return "batchAddToTrackList_\(data.id)"
        case .createTrackList: return "createTrackList"
        case .exportProgress: return "exportProgress"
        }
    }

    static func == (lhs: AppSheet, rhs: AppSheet) -> Bool {
        lhs.id == rhs.id
    }

    /// Тип sheet без payload для принятия решений после dismiss.
    var kind: AppSheetKind {
        switch self {
        case .moveToFolder: return .moveToFolder
        case .trackDetail,
             .trackDetailEdit: return .trackDetail
        case .addToTrackList: return .addToTrackList
        case .renameTrackList: return .renameTrackList
        case .renameTrackFile: return .renameTrackFile
        case .saveTrackList: return .saveTrackList
        case .newTrackListSelection: return .newTrackListSelection
        case .batchTagEdit: return .batchTagEdit
        case .batchFilenameRename: return .batchFilenameRename
        case .batchAddToTrackList: return .batchAddToTrackList
        case .createTrackList: return .createTrackList
        case .exportProgress: return .exportProgress
        }
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

    /// Тип последнего закрытого sheet для точечной реакции экранов на dismiss.
    @Published private(set) var lastDismissedSheetKind: AppSheetKind?

    /// Flow массового редактирования тегов.
    @Published var batchTagEditFlow = BatchTagEditFlow(
        pendingAction: nil,
        phase: .editing,
        tracks: [],
        fields: [],
        trackFieldOverrides: [:],
        artwork: BatchTagArtworkEditState(
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

    /// Проверяет, не открыт ли уже sheet массового переименования.
    private var isBatchFilenameRenamePresentedOrPending: Bool {
        if case .batchFilenameRename = activeSheet {
            return true
        }

        if case .batchFilenameRename = pendingSheet {
            return true
        }

        return false
    }

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
        lastDismissedSheetKind = dismissedSheet?.kind

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
        let data = MoveToFolderSheetData(
            track: track,
            operation: .move
        )
        present(.moveToFolder(data))
    }

    /// Открывает существующий выбор папки для будущего копирования iTunes-трека.
    func presentCopyPurchasedITunesToFolder(
        for track: PurchasedITunesPlayableTrack
    ) {
        let data = MoveToFolderSheetData(
            track: track,
            operation: .copyPurchasedITunes
        )
        present(.moveToFolder(data))
    }

    func presentTrackDetail(_ track: any TrackDisplayable) {
        present(.trackDetail(track))
    }

    /// Открывает карточку трека сразу в режиме редактирования тегов.
    func presentTrackDetailForEditing(_ track: any TrackDisplayable) {
        present(.trackDetailEdit(track))
    }

    func presentAddToTrackList(
        for track: any TrackDisplayable,
        sourceTrackListId: UUID? = nil
    ) {
        let data = AddToTrackListSheetData(
            track: track,
            sourceTrackListId: sourceTrackListId
        )
        present(.addToTrackList(data))
    }

    /// Открывает существующий sheet выбора треклиста для массового добавления из фонотеки.
    func presentBatchAddToTrackList(for tracks: [LibraryTrack]) {
        guard !tracks.isEmpty else { return }

        let data = AddToTrackListSheetData(
            libraryBatchTracks: tracks
        )
        present(.batchAddToTrackList(data))
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
    func presentBatchTagEdit(
        flow: BatchTagEditFlow,
        onSave: @escaping () async -> Void
    ) {
        batchTagEditFlow = flow
        present(
            .batchTagEdit(
                BatchTagEditSheetData(
                    id: UUID(),
                    onSave: onSave
                )
            )
        )
    }

    /// Показывает sheet массового переименования файлов.
    func presentBatchFilenameRename(
        flow: BatchFilenameRenameFlow,
        playerManager: PlayerManager,
        onApply: @escaping () async -> Void
    ) {
        guard !isBatchFilenameRenamePresentedOrPending else { return }

        let data = BatchFilenameRenameSheetData(
            flow: flow,
            playerManager: playerManager,
            onApply: onApply
        )

        present(.batchFilenameRename(data))
    }

    /// Сбрасывает временные состояния sheet после закрытия.
    private func resetTransientStateIfNeeded(for sheet: AppSheet?) {
        switch sheet {
        case .batchTagEdit:
            resetBatchTagEditFlow()

        case .batchFilenameRename(let data):
            data.flow.reset()

        case .moveToFolder,
             .trackDetail,
             .trackDetailEdit,
             .addToTrackList,
             .batchAddToTrackList,
             .renameTrackList,
             .renameTrackFile,
             .saveTrackList,
             .newTrackListSelection,
             .createTrackList,
             .exportProgress,
             nil:
            return
        }
    }

    /// Сбрасывает flow массового редактирования тегов.
    private func resetBatchTagEditFlow() {
        batchTagEditFlow = BatchTagEditFlow(
            pendingAction: nil,
            phase: .editing,
            tracks: [],
            fields: [],
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
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
        case .trackDetailEdit(let t): return t.id
        case .addToTrackList(let data): return data.firstTrack?.id
        case .renameTrackList: return nil
        case .renameTrackFile(let data): return data.rowId
        case .saveTrackList: return nil
        case .newTrackListSelection: return nil
        case .batchTagEdit: return nil
        case .batchFilenameRename: return nil
        case .batchAddToTrackList(let data): return data.firstTrack?.id
        case .createTrackList: return nil
        case .exportProgress: return nil
        }
    }
}

// MARK: - TrackListsPresenting

extension SheetManager: TrackListsPresenting {}
