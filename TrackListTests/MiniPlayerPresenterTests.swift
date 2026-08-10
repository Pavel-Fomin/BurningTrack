//
//  MiniPlayerPresenterTests.swift
//  TrackListTests
//
//  Проверки presentation-правил MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class MiniPlayerPresenterTests: XCTestCase {

    private let presenter = MiniPlayerPresenter()

    /// Пустой Player state формирует локализованный fallback без доступных действий.
    func testEmptyStateUsesFallbackContentAndDisablesActions() {
        let state = presenter.present(
            miniPlayerState: .empty,
            waveformState: .unavailable,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: nil,
            initialIsExpanded: false
        )

        XCTAssertEqual(state.title, String(localized: "Nothing Playing"))
        XCTAssertEqual(state.artist, "")
        XCTAssertFalse(state.isPlaybackEnabled)
        XCTAssertFalse(state.isFavoriteEnabled)
        XCTAssertFalse(state.canShowCurrentTrackInLibrary)
    }

    /// Loading без static state показывает самостоятельный presentation fallback.
    func testLoadingWithoutStaticStateUsesLoadingFallback() {
        let state = presenter.present(
            miniPlayerState: .loading(staticState: nil),
            waveformState: .loading,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: nil,
            initialIsExpanded: true
        )

        XCTAssertEqual(state.title, String(localized: "Loading Track"))
        XCTAssertEqual(state.artist, "")
        XCTAssertEqual(state.waveformState, .loading)
        XCTAssertTrue(state.initialIsExpanded)
    }

    /// Loading со static state сохраняет уже доступные metadata до начала playback.
    func testLoadingWithStaticStateKeepsTrackContent() {
        let staticState = makeStaticState(title: "Preparing", artist: "Artist")

        let state = presenter.present(
            miniPlayerState: .loading(staticState: staticState),
            waveformState: .unavailable,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertEqual(state.title, "Preparing")
        XCTAssertEqual(state.artist, "Artist")
        XCTAssertTrue(state.isPlaybackEnabled)
    }

    /// Playing переносит progress и признак воспроизведения в готовую View-модель.
    func testPlayingStateUsesProgressContent() {
        let staticState = makeStaticState(title: "Playing", artist: "Artist")
        let progress = MiniPlayerProgressState(
            isPlaying: true,
            currentTime: 42,
            duration: 180
        )

        let state = presenter.present(
            miniPlayerState: .playing(staticState: staticState, progressState: progress),
            waveformState: .ready([0.2, 0.8]),
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertEqual(state.title, "Playing")
        XCTAssertEqual(state.currentTime, 42)
        XCTAssertEqual(state.duration, 180)
        XCTAssertTrue(state.isPlaying)
    }

    /// Paused не меняет metadata и передаёт фактическое состояние progress без собственных догадок View.
    func testPausedStateUsesProgressContent() {
        let staticState = makeStaticState(title: "Paused", artist: "Artist")
        let progress = MiniPlayerProgressState(
            isPlaying: false,
            currentTime: 84,
            duration: 180
        )

        let state = presenter.present(
            miniPlayerState: .paused(staticState: staticState, progressState: progress),
            waveformState: .ready([0.4]),
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertEqual(state.title, "Paused")
        XCTAssertEqual(state.currentTime, 84)
        XCTAssertFalse(state.isPlaying)
    }

    /// Error остаётся корректным presentation case независимо от текущей production-публикации Player state.
    func testErrorStateUsesFallbackContentAndDisablesLibraryRouting() {
        let state = presenter.present(
            miniPlayerState: .error,
            waveformState: .failed,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertEqual(state.title, String(localized: "Playback Error"))
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.canShowCurrentTrackInLibrary)
    }

    /// Подтверждённое favorite state и режимы плеера преобразуются в независимые флаги разметки.
    func testFavoriteAndPlaybackModeBecomePresentationFlags() {
        let staticState = makeStaticState(title: "Track", artist: "Artist")
        let progress = MiniPlayerProgressState(isPlaying: true, currentTime: 1, duration: 2)
        let mode = PlaybackMode(isShuffleEnabled: false, repeatMode: .one)

        let state = presenter.present(
            miniPlayerState: .playing(staticState: staticState, progressState: progress),
            waveformState: .unavailable,
            isCurrentTrackFavorite: true,
            playbackMode: mode,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertTrue(state.isFavorite)
        XCTAssertTrue(state.isFavoriteEnabled)
        XCTAssertFalse(state.isShuffleEnabled)
        XCTAssertFalse(state.isRepeatAllEnabled)
        XCTAssertTrue(state.isRepeatOneEnabled)
    }

    /// Доступность перехода определяется presenter-правилом, а не запросом View к action handler.
    func testLibraryTrackCanBeShownInLibrary() {
        let staticState = makeStaticState(title: "Track", artist: "Artist")
        let progress = MiniPlayerProgressState(isPlaying: true, currentTime: 1, duration: 2)

        let state = presenter.present(
            miniPlayerState: .playing(staticState: staticState, progressState: progress),
            waveformState: .unavailable,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertTrue(state.canShowCurrentTrackInLibrary)
    }

    /// Отсутствующий artist использует единый presentation fallback, а не логику SwiftUI View.
    func testMissingArtistUsesPresentationFallback() {
        let staticState = makeStaticState(title: "Track", artist: nil)
        let progress = MiniPlayerProgressState(isPlaying: false, currentTime: 0, duration: 1)

        let state = presenter.present(
            miniPlayerState: .paused(staticState: staticState, progressState: progress),
            waveformState: .unavailable,
            isCurrentTrackFavorite: false,
            playbackMode: .defaultValue,
            currentTrackDisplayable: makeLibraryTrack(),
            initialIsExpanded: false
        )

        XCTAssertEqual(state.artist, String(localized: "Unknown Artist"))
    }

    /// Создаёт static state, достаточный исключительно для проверки presentation-правил.
    private func makeStaticState(
        title: String,
        artist: String?
    ) -> MiniPlayerStaticState {
        MiniPlayerStaticState(
            trackId: UUID(),
            title: title,
            artist: artist,
            artworkRequest: nil
        )
    }

    /// Создаёт локальный трек для сценариев доступности и включённых действий.
    private func makeLibraryTrack() -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/MiniPlayer.m4a"),
            title: "Track",
            artist: "Artist",
            duration: 180,
            addedDate: Date()
        )
    }
}
