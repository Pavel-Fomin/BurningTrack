//
//  TrackDetailSheet.swift
//  TrackList
//
//  Экран "О треке" — глобальный sheet для просмотра информации о треке
//  Отображает обложку, имя файла, теги и технические данные
//
//  Created by Pavel Fomin on 13.10.2025.
//

import SwiftUI

struct TrackDetailSheet: View {

    let track: any TrackDisplayable

    // MARK: - Runtime state

    @State private var resolvedURL: URL?
    @State private var artworkImage: Image?
    @State private var tags: [(String, String)] = []

    // MARK: - Future editing support (пока НЕ используется)

    enum EditableField: Hashable {
        case title, artist, album, genre, comment
    }

    @State private var editingField: EditableField? = nil
    @State private var editableValues: [EditableField: String] = [:]

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Artwork

            if let artworkImage {
                artworkImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.vertical, 20)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
                    .padding(.vertical, 20)
            }

            // MARK: - Info list

            List {

                // Путь к файлу
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПУТЬ К ФАЙЛУ")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let url = resolvedURL {
                        Text(displayPath(from: url))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .monospaced()
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }

                // Имя файла
                VStack(alignment: .leading, spacing: 6) {
                    Text("НАЗВАНИЕ ФАЙЛА")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let url = resolvedURL {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }

                // Теги
                ForEach(tags, id: \.0) { key, value in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label(for: key).uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(value.isEmpty ? "—" : value)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(4)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .scrollContentBackground(.hidden)
        .background(.clear)

        // MARK: - URL + TagLib (один осознанный IO-проход)

        .task {
            guard let url = await BookmarkResolver.url(forTrack: track.id) else {
                print("❌ BookmarkResolver: нет URL для трека \(track.id)")
                return
            }

            resolvedURL = url
            await loadMetadataFromTagLib(url: url)
        }

        // MARK: - Artwork (ТОЛЬКО из cache, без IO)

        .task(id: resolvedURL) {
            guard
                let url = resolvedURL,
                let cached = TrackMetadataCacheManager.shared
                    .loadMetadataFromCache(url: url)
            else { return }

            let image = ArtworkProvider.shared.image(
                trackId: track.id,
                artworkData: cached.artworkData,
                purpose: .trackInfoSheet
            )

            if let image {
                artworkImage = Image(uiImage: image)
            }
        }

        // MARK: - Background

        .background(
            ZStack {
                Color(.systemGroupedBackground).opacity(0.25)
                Color.black.opacity(0.1)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: artworkImage)
        )
    }

    // MARK: - TagLib (read-only, подготовлено под inline-edit)

    private func loadMetadataFromTagLib(url: URL) async {
        let tagFile = TLTagLibFile(fileURL: url)

        guard let parsed = tagFile.readMetadata() else {
            await MainActor.run { tags = [] }
            return
        }

        let result: [(String, String)] = [
            ("title", parsed.title ?? ""),
            ("artist", parsed.artist ?? ""),
            ("album", parsed.album ?? ""),
            ("genre", parsed.genre ?? ""),
            ("comment", parsed.comment ?? "")
        ].map { ($0.0, $0.1.trimmingCharacters(in: .whitespacesAndNewlines)) }

        await MainActor.run {
            tags = result
        }
    }

    // MARK: - Labels

    private func label(for key: String) -> String {
        switch key {
        case "title": return "Название трека"
        case "artist": return "Исполнитель"
        case "album": return "Альбом"
        case "genre": return "Жанр"
        case "comment": return "Комментарий"
        default: return key.capitalized
        }
    }

    // MARK: - Path formatting

    private func displayPath(from url: URL) -> String {
        let path = url.path

        if let range = path.range(of: "/File Provider Storage/") {
            let trimmed = String(path[range.upperBound...])
            return "iPhone: \(URL(fileURLWithPath: trimmed).deletingLastPathComponent().path)"
        }

        if let range = path.range(of: "/Mobile Documents/") {
            let trimmed = String(path[range.upperBound...])
            return "iCloud: \(URL(fileURLWithPath: trimmed).deletingLastPathComponent().path)"
        }

        return url.deletingLastPathComponent().lastPathComponent
    }
}
