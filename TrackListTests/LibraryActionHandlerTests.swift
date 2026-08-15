//
//  LibraryActionHandlerTests.swift
//  TrackListTests
//
//  Проверяет typed lifecycle и picker intents корневого flow фонотеки.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Combine
import XCTest
@testable import TrackList

@MainActor
final class LibraryActionHandlerTests: XCTestCase {
    func testAddFolderActionPublishesFolderPickerIntentThroughOutput() {
        let output = LibraryMasterActionOutputSpy()
        let handler = makeMasterActionHandler(
            output: output,
            toastPresenter: LibraryToastPresenterSpy()
        )

        handler.handle(.addFolderTapped)

        XCTAssertEqual(output.folderPickerRequestCount, 1)
    }

    func testFolderPickFailedActionIsRoutedToToastPresenter() {
        let output = LibraryMasterActionOutputSpy()
        let toastPresenter = LibraryToastPresenterSpy()
        let handler = makeMasterActionHandler(
            output: output,
            toastPresenter: toastPresenter
        )

        handler.handle(.folderPickFailed)

        XCTAssertEqual(toastPresenter.events.count, 1)
    }

    func testCollectionRootLifecycleActionsAreRoutedOnlyThroughScreenActionHandler() {
        let output = LibraryScreenActionOutputSpy()
        let handler = LibraryScreenActionHandler(
            navigationCoordinator: .shared,
            musicLibraryManager: .shared,
            trackRegistry: .shared,
            toastPresenter: LibraryToastPresenterSpy()
        )
        handler.configure(output: output)

        handler.handle(.collectionRootAppeared)
        handler.handle(.collectionRootDisappeared)

        XCTAssertEqual(output.collectionRootVisibilityChanges, [true, false])
    }

    private func makeMasterActionHandler(
        output: LibraryMasterActionOutputSpy,
        toastPresenter: any ToastPresenting
    ) -> LibraryMasterActionHandler {
        LibraryMasterActionHandler(
            manager: .shared,
            navigationCoordinator: .shared,
            toastPresenter: toastPresenter,
            playbackState: LibraryPlaybackStateProviderSpy(),
            playbackController: LibraryPlaybackControllerSpy(),
            output: output
        )
    }
}

/// Фиксирует только presentation intent и не выполняет операции с реальными папками.
@MainActor
private final class LibraryMasterActionOutputSpy: LibraryMasterActionOutput {
    var pendingDetachFolder: LibraryFolder?
    private(set) var folderPickerRequestCount = 0

    func refreshState() {}

    func requestFolderPicker() {
        folderPickerRequestCount += 1
    }

    func requestDetachFolderConfirmation(_: LibraryFolder) {}

    func dismissDetachFolderConfirmation() {}

    func showPlayingTrackDetachWarning(for _: LibraryFolder) {}

    func clearPendingDetachFolder() {}

    func moveFolder(from _: IndexSet, to _: Int) {}
}

/// Фиксирует lifecycle collection root без создания LibraryScreenViewModel.
@MainActor
private final class LibraryScreenActionOutputSpy: LibraryScreenActionHandlingOutput {
    private(set) var collectionRootVisibilityChanges: [Bool] = []

    func setCollectionRootVisibility(_ isVisible: Bool) {
        collectionRootVisibilityChanges.append(isVisible)
    }
}

/// Не показывает UIKit, но сохраняет факт пользовательского сообщения.
@MainActor
private final class LibraryToastPresenterSpy: ToastPresenting {
    private(set) var events: [ToastEvent] = []
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration _: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Возвращает статичный playback snapshot для сценариев, которые не должны управлять плеером.
@MainActor
private final class LibraryPlaybackStateProviderSpy: PlaybackStateProviding {
    private let state = PlaybackStateSnapshot(
        currentDisplayableId: nil,
        currentTrackId: nil,
        currentContext: nil,
        currentContextSource: nil,
        isPlaying: false
    )

    var playbackState: PlaybackStateSnapshot { state }
    var currentDisplayableId: UUID? { state.currentDisplayableId }
    var currentTrackId: UUID? { state.currentTrackId }
    var currentContext: PlaybackContext? { state.currentContext }
    var currentContextSource: PlaybackContextSource? { state.currentContextSource }
    var isPlaying: Bool { state.isPlaying }
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        Just(state).eraseToAnyPublisher()
    }
}

/// Не выполняет команду плеера в тестах корневого flow.
@MainActor
private final class LibraryPlaybackControllerSpy: TrackPlaybackControlling {
    func togglePlayPause() {}

    func play(
        track _: any TrackDisplayable,
        context _: [any TrackDisplayable],
        source _: PlaybackContextSource
    ) {}
}
