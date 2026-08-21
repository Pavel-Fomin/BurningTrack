//
//  LibraryFolderActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта треков из открытой папки фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Combine
import Foundation
import XCTest
@testable import TrackList

/// Проверяет действия открытой папки без запуска picker-а и копирования файлов.
@MainActor
final class LibraryFolderActionHandlerTests: XCTestCase {

    /// Проверяет экспорт только видимых треков в отображаемом порядке и без нумерации имён.
    func testExportUsesVisibleTracksInDisplayOrderWithOriginalFileNames() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let folder = makeFolder(name: "Текущая папка")
        let viewModel = makeViewModel(
            folder: folder,
            exportRequestHandler: exportRequestHandler
        )
        let firstTrack = makeLibraryTrack(fileName: "01 First.flac")
        let secondTrack = makeLibraryTrack(fileName: "02 Second.FLAC")
        let nestedTrack = makeLibraryTrack(fileName: "Nested.flac")

        viewModel.handle(.exportTracks([secondTrack, firstTrack]))

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            [secondTrack.trackId, firstTrack.trackId]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.fileName),
            [secondTrack.fileName, firstTrack.fileName]
        )
        XCTAssertFalse(
            exportRequestHandler.requests.first?.tracks.map(\.trackId).contains(nestedTrack.trackId) == true
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .named(folder.name))
        guard let fileNamingMode = exportRequestHandler.requests.first?.fileNamingMode else {
            return XCTFail("Режим именования не был передан в ExportRequest")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для экспорта папки ожидался режим original")
        }
    }

    /// Проверяет, что пустой список видимых треков не запускает экспорт.
    func testEmptyVisibleTracksPassEmptyRequestToGlobalValidation() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let viewModel = makeViewModel(
            folder: makeFolder(name: "Пустая папка"),
            exportRequestHandler: exportRequestHandler
        )

        viewModel.handle(.exportTracks([]))

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
    }

    /// Проверяет сохранение существующего действия очистки панели выбора при появлении папки.
    func testAppearedClearsSelectionActionBar() {
        var clearSelectionCallCount = 0
        let viewModel = makeViewModel(
            folder: makeFolder(name: "Текущая папка"),
            exportRequestHandler: ExportRequestHandlerSpy(),
            clearSelectionActionBar: {
                clearSelectionCallCount += 1
            }
        )

        viewModel.handle(.appeared)

        XCTAssertEqual(clearSelectionCallCount, 1)
    }

    /// Проверяет сохранение существующей навигации при выборе вложенной папки.
    func testSubfolderTapPushesFolderRoute() {
        let navigationCoordinator = NavigationCoordinator.shared
        navigationCoordinator.openLibraryRoot()
        defer { navigationCoordinator.openLibraryRoot() }

        let viewModel = makeViewModel(
            folder: makeFolder(name: "Текущая папка"),
            exportRequestHandler: ExportRequestHandlerSpy()
        )
        let subfolder = makeFolder(name: "Вложенная папка")

        viewModel.handle(.subfolderTapped(subfolder))

        XCTAssertEqual(
            navigationCoordinator.libraryPath,
            [.folder(subfolder.url.libraryFolderId)]
        )
    }

    /// Собирает ViewModel папки с управляемыми зависимостями обработчика действий.
    private func makeViewModel(
        folder: LibraryFolder,
        exportRequestHandler: any ExportRequestHandling,
        clearSelectionActionBar: @escaping @MainActor () -> Void = {}
    ) -> LibraryFolderViewModel {
        let factory = LibraryFolderViewModelFactory(
            // Фабрика принимает concrete coordinator с private initializer, поэтому без изменения production-контракта
            // тест сохраняет существующий изолированный сбросом singleton только для проверки folder route.
            navigationCoordinator: .shared,
            exportRequestHandler: exportRequestHandler,
            summaryProvider: EmptyTrackCollectionSummaryProvider(),
            eventProvider: LibraryFolderEventProviderStub()
        )
        return factory.make(
            folder: folder,
            clearSelectionActionBar: clearSelectionActionBar
        )
    }

    /// Создаёт папку, название которой должно стать именем дочерней папки экспорта.
    private func makeFolder(name: String) -> LibraryFolder {
        LibraryFolder(
            name: name,
            url: URL(fileURLWithPath: "/tmp/\(name)")
        )
    }

    /// Создаёт минимальный трек фонотеки для проверки состава экспорта.
    private func makeLibraryTrack(fileName: String) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            title: "Трек",
            artist: "Артист",
            duration: 10,
            addedDate: Date()
        )
    }

}

/// Не обращается к постоянной SQLite-базе в тестах действий папки и не хранит mutable state.
private final class EmptyTrackCollectionSummaryProvider: TrackCollectionSummaryProviding, Sendable {
    /// Возвращает пустую статистику, не влияющую на проверяемые действия экспорта.
    func summaryForFolder(folderId: UUID) async throws -> TrackCollectionSummary {
        TrackCollectionSummary(
            trackCount: 0,
            totalDuration: nil,
            totalFileSize: nil,
            unknownDurationCount: 0,
            unknownFileSizeCount: 0
        )
    }

    /// Возвращает пустую статистику, так как тестовая ViewModel открывает только папку.
    func summaryForTrackList(trackListId: UUID) async throws -> TrackCollectionSummary {
        TrackCollectionSummary(
            trackCount: 0,
            totalDuration: nil,
            totalFileSize: nil,
            unknownDurationCount: 0,
            unknownFileSizeCount: 0
        )
    }
}

/// Заменяет production NotificationCenter, чтобы тесты действий папки не получали внешние события приложения.
@MainActor
private final class LibraryFolderEventProviderStub: LibraryTrackEventProvider {
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        Empty().eraseToAnyPublisher()
    }

    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> {
        Empty().eraseToAnyPublisher()
    }

    var libraryDataDidChange: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var appSettingsDidChange: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var trackListBadgesDidChange: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }
}
