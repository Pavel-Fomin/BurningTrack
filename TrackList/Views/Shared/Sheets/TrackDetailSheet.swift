//
//  TrackDetailSheet.swift
//  TrackList
//
//  Экран "О треке" — глобальный sheet.
//
//  Роль:
//  - управляет режимами просмотра и редактирования
//  - загружает данные трека (URL, теги, artwork)
//  - собирает экран из read-only и edit форм
//
//  Created by Pavel Fomin on 13.10.2025.
//

import SwiftUI

struct TrackDetailSheet: View {

    // MARK: - Input

    let track: any TrackDisplayable
    let mode: Mode

    enum Mode: Equatable {
        case view
        case edit
    }

    // MARK: - Editing state (из контейнера)

    @Binding var editedValues: [EditableTrackField: String]
    @Binding var editedFileName: String

    // MARK: - Runtime state

    @State private var resolvedURL: URL?
    @State private var artworkUIImage: UIImage?
    @State private var didLoad = false


    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            switch mode {
            case .view:
                TrackDetailReadOnlyView(
                    artworkUIImage: artworkUIImage,
                    filePath: resolvedURL.map {
                        displayPath(from: $0.deletingLastPathComponent())
                    },
                    fileName: editedFileName,
                    tags: [
                        ("Название трека", editedValues[.title] ?? ""),
                        ("Исполнитель", editedValues[.artist] ?? ""),
                        ("Альбом", editedValues[.album] ?? ""),
                        ("Жанр", editedValues[.genre] ?? ""),
                        ("Комментарий", editedValues[.comment] ?? "")
                    ]
                )

            case .edit:
                TrackDetailEditForm(
                    fileName: $editedFileName,
                    values: $editedValues,
                    artworkUIImage: artworkUIImage
                )
            }
        }
        .task {
            if didLoad { return }
            didLoad = true
            await load()
        }
    }


    // MARK: - Load data

    private func load() async {
        guard let url = await BookmarkResolver.url(forTrack: track.id) else {
            print("❌ BookmarkResolver: нет URL для трека \(track.id)")
            return
        }

        resolvedURL = url
        editedFileName = url.deletingPathExtension().lastPathComponent

        await loadMetadata(from: url)
        loadArtwork(from: url)
    }

    private func loadMetadata(from url: URL) async {
        let tagFile = TLTagLibFile(fileURL: url)

        guard let parsed = tagFile.readMetadata() else {
            return
        }

        await MainActor.run {

            editedValues = [
                .title: parsed.title ?? "",
                .artist: parsed.artist ?? "",
                .album: parsed.album ?? "",
                .genre: parsed.genre ?? "",
                .comment: parsed.comment ?? ""
            ]
        }
    }

    private func loadArtwork(from url: URL) {
        guard
            let cached = TrackMetadataCacheManager.shared.loadMetadataFromCache(url: url),
            let image = ArtworkProvider.shared.image(
                trackId: track.id,
                artworkData: cached.artworkData,
                purpose: .trackInfoSheet
            )
        else { return }

        artworkUIImage = image
    }

    // MARK: - Helpers

    private func displayPath(from url: URL) -> String {
        let path = url.path

        if let range = path.range(of: "/File Provider Storage/") {
            return "iPhone: " + String(path[range.upperBound...])
        }

        if let range = path.range(of: "/Mobile Documents/") {
            return "iCloud: " + String(path[range.upperBound...])
        }

        return url.deletingLastPathComponent().lastPathComponent
    }
}
