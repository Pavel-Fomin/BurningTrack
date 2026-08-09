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

// MARK: - Данные для TrackDetailSheet

/// Неизменяемый route карточки трека.
///
/// `id` описывает конкретное открытие sheet, а не доменную идентичность трека:
/// один и тот же трек может быть открыт повторно после закрытия предыдущего route.
struct TrackDetailSheetData: Identifiable, Equatable {
    let id = UUID()
    let track: any TrackDisplayable
    let initialMode: TrackDetailMode

    static func == (
        lhs: TrackDetailSheetData,
        rhs: TrackDetailSheetData
    ) -> Bool {
        lhs.id == rhs.id
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

// MARK: - Данные для CreateTrackListSheet

/// Идентичность одного открытия формы создания треклиста.
struct CreateTrackListSheetData: Identifiable, Equatable {
    let id = UUID()

    static func == (
        lhs: CreateTrackListSheetData,
        rhs: CreateTrackListSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
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

    /// Зафиксированное массовое действие для feature-local загрузки metadata.
    let pendingAction: PendingBulkTrackAction

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
    /// Идентификатор конкретного открытия sheet.
    let id: UUID

    /// Зафиксированное массовое действие текущей feature-сессии.
    let pendingAction: PendingBulkTrackAction

    /// Неизменяемый снимок строк, позволяющий sheet открыться до загрузки runtime metadata.
    let tracks: [BatchFilenameRenameTrackSeed]

    static func == (
        lhs: BatchFilenameRenameSheetData,
        rhs: BatchFilenameRenameSheetData
    ) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Перечень шитов

enum AppSheet: Identifiable, Equatable {
    case moveToFolder(MoveToFolderSheetData)
    case trackDetail(TrackDetailSheetData)
    case addToTrackList(AddToTrackListSheetData)
    case renameTrackList(RenameTrackListSheetData)
    case renameTrackFile(RenameTrackFileSheetData)
    case saveTrackList(SaveTrackListSheetData)
    case newTrackListSelection(NewTrackListSelectionSheetData)
    case batchTagEdit(BatchTagEditSheetData)
    case batchFilenameRename(BatchFilenameRenameSheetData)
    case batchAddToTrackList(AddToTrackListSheetData)
    case createTrackList(CreateTrackListSheetData)
    case exportProgress(ExportDetailsSheetRoute)
    

    var id: String {
        switch self {
        case .moveToFolder(let data): return "moveToFolder_\(data.id)"
        case .trackDetail(let data): return "trackDetail_\(data.id)"
        case .addToTrackList(let data): return "addToTrackList_\(data.id)"
        case .renameTrackList(let data): return "renameTrackList_\(data.id)"
        case .renameTrackFile(let data): return "renameTrackFile_\(data.id)"
        case .saveTrackList(let data): return "saveTrackList_\(data.id)"
        case .newTrackListSelection(let data): return "newTrackListSelection_\(data.id)"
        case .batchTagEdit(let data): return "batchTagEdit_\(data.id)"
        case .batchFilenameRename(let data): return "batchFilenameRename_\(data.id)"
        case .batchAddToTrackList(let data): return "batchAddToTrackList_\(data.id)"
        case .createTrackList(let data): return "createTrackList_\(data.id)"
        case .exportProgress(let route): return "exportProgress_\(route.id)"
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

    /// Текущий отображаемый sheet.
    ///
    /// SwiftUI при интерактивном закрытии сначала записывает `nil` в binding,
    /// а затем вызывает `onDismiss`. Поэтому здесь фиксируется route, который
    /// действительно начал закрываться, если закрытие инициировано не через `closeActive()`.
    @Published var activeSheet: AppSheet? {
        didSet {
            guard activeSheet == nil,
                  let previouslyActiveSheet = oldValue,
                  dismissingSheet == nil else {
                return
            }

            dismissingSheet = previouslyActiveSheet
        }
    }

    /// Sheet, закрытие которого уже началось и ожидает подтверждения от SwiftUI `onDismiss`.
    /// Хранится отдельно от `activeSheet`, чтобы новый route не мог быть принят за закрытый.
    private var dismissingSheet: AppSheet?

    /// Единственный следующий sheet, который откроется после подтверждённого dismiss.
    /// При повторном запросе во время закрытия последнее намерение заменяет предыдущее.
    private var pendingSheet: AppSheet?

    /// ID строки для выделения в списках
    @Published var highlightedRowID: UUID?
    
    /// Основной код приложения использует `shared`, а internal-инициализатор нужен целевым
    /// модульным тестам для проверки независимого жизненного цикла без изменения глобального состояния приложения.
    init() {}


    // MARK: - ОСНОВНОЙ МЕТОД ПОКАЗА ШИТОВ

    func present(_ sheet: AppSheet) {
        guard activeSheet == nil, dismissingSheet == nil else {
            replaceActive(with: sheet)
            return
        }

        presentImmediately(sheet)
    }

    /// Атомарно заменяет текущий sheet следующим route.
    ///
    /// Новый route не назначается в `activeSheet` до `onDismiss`: это сохраняет
    /// связь между системным dismiss и route, для которого нужно очистить временное состояние.
    func replaceActive(with sheet: AppSheet) {
        if activeSheet != nil {
            pendingSheet = sheet
            closeActive()
            return
        }

        if dismissingSheet != nil {
            // Одного pending route достаточно для текущих сценариев. Последний запрос
            // отражает актуальное пользовательское намерение и заменяет предыдущий.
            pendingSheet = sheet
            return
        }

        presentImmediately(sheet)
    }


    // MARK: - ЗАКРЫТИЕ И ПОДТВЕРЖДЕНИЕ DISMISS

    /// Начинает закрытие текущего sheet без назначения следующего route.
    func closeActive() {
        guard let activeSheet else { return }

        dismissingSheet = activeSheet
        self.activeSheet = nil
    }

    // MARK: - ВЫЗЫВАЕТСЯ ИЗ ContentView.onDismiss
  
    func handleDismiss() {
        guard let dismissedSheet = dismissingSheet else {
            return
        }

        dismissingSheet = nil
        if let next = pendingSheet {
            pendingSheet = nil
            presentImmediately(next)
        } else {
            highlightedRowID = nil
        }
    }

    /// Назначает route только тогда, когда никакой dismiss не ожидает подтверждения.
    private func presentImmediately(_ sheet: AppSheet) {
        activeSheet = sheet
        highlightedRowID = sheet.relatedRowId
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
        present(
            .trackDetail(
                TrackDetailSheetData(
                    track: track,
                    initialMode: .view
                )
            )
        )
    }

    /// Открывает карточку трека сразу в режиме редактирования тегов.
    func presentTrackDetailForEditing(_ track: any TrackDisplayable) {
        present(
            .trackDetail(
                TrackDetailSheetData(
                    track: track,
                    initialMode: .edit
                )
            )
        )
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
        present(.createTrackList(CreateTrackListSheetData()))
    }

    // MARK: - Route-specific dismiss

    /// Закрывает только совпадающий route выбора папки.
    func dismissMoveToFolder(_ routeID: UUID) {
        guard case let .moveToFolder(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route карточки трека.
    func dismissTrackDetail(_ routeID: UUID) {
        guard case let .trackDetail(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route добавления в треклист.
    func dismissAddToTrackList(_ routeID: UUID) {
        guard let activeSheet else {
            return
        }

        let activeRouteID: UUID
        switch activeSheet {
        case let .addToTrackList(data), let .batchAddToTrackList(data):
            activeRouteID = data.id

        default:
            return
        }

        guard activeRouteID == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route переименования треклиста.
    func dismissRenameTrackList(_ routeID: UUID) {
        guard case let .renameTrackList(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route ручного переименования файла.
    func dismissRenameTrackFile(_ routeID: UUID) {
        guard case let .renameTrackFile(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route сохранения очереди.
    func dismissSaveTrackList(_ routeID: UUID) {
        guard case let .saveTrackList(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route выбора треков для треклиста.
    func dismissNewTrackListSelection(_ routeID: UUID) {
        guard case let .newTrackListSelection(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route массового редактирования тегов.
    func dismissBatchTagEdit(_ routeID: UUID) {
        guard case let .batchTagEdit(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route массового переименования файлов.
    func dismissBatchFilenameRename(_ routeID: UUID) {
        guard case let .batchFilenameRename(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Закрывает только совпадающий route создания треклиста.
    func dismissCreateTrackList(_ routeID: UUID) {
        guard case let .createTrackList(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        closeActive()
    }

    /// Заменяет текущую форму создания выбором треков только для исходного route.
    func presentTrackSelectionForCreate(
        name: String,
        from routeID: UUID
    ) {
        guard case let .createTrackList(data)? = activeSheet,
              data.id == routeID else {
            return
        }

        replaceActive(
            with: .newTrackListSelection(
                NewTrackListSelectionSheetData(
                    mode: .create(trackListName: name)
                )
            )
        )
    }

}


// MARK: - Вспомогательная логика извлечения id строки из enum AppSheet

private extension AppSheet {
    var relatedRowId: UUID? {
        switch self {
        case .moveToFolder(let d): return d.track.id
        case .trackDetail(let data): return data.track.id
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

// MARK: - ExportDetailsRouting

extension SheetManager: ExportDetailsRouting {

    /// Открывает глобальный sheet с неизменяемой идентичностью конкретного Export route.
    func presentExportDetails() -> ExportDetailsSheetRoute {
        if case let .exportProgress(route)? = activeSheet {
            return route
        }

        let route = ExportDetailsSheetRoute()
        present(.exportProgress(route))
        return route
    }

    /// Закрывает только совпадающий активный route подробностей экспорта.
    func dismissExportDetails(_ route: ExportDetailsSheetRoute) {
        guard case let .exportProgress(activeRoute)? = activeSheet,
              activeRoute == route else {
            return
        }

        closeActive()
    }
}
