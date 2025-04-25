//
//  AudioTrack+Mock.swift
//  TrackList
//
//  Created by Pavel Fomin on 25.04.2025.
//

import Foundation

#if DEBUG
extension AudioTrack {
    static let mock = AudioTrack(
        url: URL(fileURLWithPath: "/mock/path.mp3"),
        artist: "Mock Artist",
        title: "Mock Title",
        filename: "mock.mp3",
        duration: 240,
        artwork: nil
    )

    static let mockList: [AudioTrack] = Array(repeating: .mock, count: 5)

    static let mockExporting = AudioTrack(
        url: mock.url,
        artist: mock.artist,
        title: mock.title,
        filename: mock.filename,
        duration: mock.duration,
        artwork: mock.artwork,
        isExporting: true
    )
}
#endif
