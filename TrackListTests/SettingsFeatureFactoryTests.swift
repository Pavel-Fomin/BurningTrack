//
// "SettingsFeatureFactoryTests.swift"
// TrackList
// Проверяет внедрение SettingsManaging в factory и реактивное состояние экрана.
// Created by Pavel Fomin on 13.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class SettingsFeatureFactoryTests: XCTestCase {
    func testFactoryRoutesActionToInjectedSettingsManager() {
        let manager = SettingsManagingSpy()
        let viewModel = SettingsFeatureFactory(settingsManager: manager)
            .makeViewModel()

        viewModel.handle(.setFileFormatVisible(false))

        XCTAssertEqual(manager.fileFormatValues, [false])
        XCTAssertFalse(viewModel.state.isFileFormatVisible)
    }

    func testSettingsPublisherUpdatesScreenState() {
        let manager = SettingsManagingSpy()
        let viewModel = SettingsFeatureFactory(settingsManager: manager)
            .makeViewModel()

        manager.setTagReadingEnabled(false)

        XCTAssertFalse(viewModel.state.isTagReadingEnabled)
    }
}

/// Изолирует Settings feature от SQLite и фиксирует действия ActionHandler.
@MainActor
private final class SettingsManagingSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue
    private(set) var fileFormatValues: [Bool] = []

    var settings: AppSettings { currentSettings }

    var settingsPublisher: Published<AppSettings>.Publisher { $currentSettings }

    func setTagReadingEnabled(_ value: Bool) {
        currentSettings.visible.metadata.isTagReadingEnabled = value
    }

    func setTrackListMembershipVisible(_ value: Bool) {
        currentSettings.visible.library.isTrackListMembershipVisible = value
    }

    func setFileFormatVisible(_ value: Bool) {
        fileFormatValues.append(value)
        currentSettings.visible.library.isFileFormatVisible = value
    }

    func setPurchasedITunesSourceVisible(_ value: Bool) {
        currentSettings.visible.library.isPurchasedITunesSourceVisible = value
    }

    func setMiniPlayerExpanded(_ value: Bool) {
        currentSettings.internalSettings.isMiniPlayerExpanded = value
    }

    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {
        currentSettings.internalSettings.libraryRootDisplayMode = mode
    }

    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {
        currentSettings.internalSettings.libraryTrackSortMode = mode
    }

    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {
        currentSettings.internalSettings.trackListsSortMode = mode
    }
}
