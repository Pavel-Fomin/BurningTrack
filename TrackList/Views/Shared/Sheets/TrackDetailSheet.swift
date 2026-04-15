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
                        ("Год выпуска", editedValues[.year] ?? ""),
                        ("Лейбл / издатель", editedValues[.publisher] ?? ""),
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

        await loadMetadataAndArtwork(from: url)
    }


    private func loadMetadataAndArtwork(from url: URL) async {

        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }

        guard let metadata = TrackTagInspector.shared.readMetadata(from: url) else {
            return
        }

        let values: [EditableTrackField: String] = [
            .title: metadata.title ?? "",
            .artist: metadata.artist ?? "",
            .album: metadata.album ?? "",
            .genre: metadata.genre ?? "",
            .year: metadata.year.map(String.init) ?? "",
            .publisher: metadata.publisherOrLabel ?? "",
            .comment: metadata.comment ?? ""
        ]

        // Обложку пока продолжаем читать отдельно,
        // потому что TrackSheetMetadata её ещё не хранит.
        let tagFile = TLTagLibFile(fileURL: url)
        let parsed = tagFile.readMetadata()

        let image = ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: parsed?.artworkData,
            purpose: .trackInfoSheet
        )

        await MainActor.run {
            editedValues = values
            artworkUIImage = image
        }
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
