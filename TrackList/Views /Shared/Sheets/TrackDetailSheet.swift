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
    let fileURL: URL
    
    @State private var artwork: UIImage? = nil
    @State private var tags: [(String, String)] = []
    
// MARK: - Обложка+Список
    var body: some View {
        VStack(spacing: 0) {
            // Обложка
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            }

            // Список тегов
            List {
                // 1) Путь к файлу
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПУТЬ К ФАЙЛУ")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(displayPath(from: fileURL))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .monospaced()
                }

                // 2) Имя файла
                VStack(alignment: .leading, spacing: 6) {
                    Text("НАЗВАНИЕ ФАЙЛА")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(fileURL.deletingPathExtension().lastPathComponent)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }

                // 3) Теги из TagLib
                ForEach(tags, id: \.0) { key, value in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(label(for: key).uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(value.isEmpty ? "—" : value)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .task { await loadMetadata() }
        .background(
            ZStack {
                (artwork?.averageColor ?? Color(.systemGroupedBackground))
                    .opacity(0.25) // базовый цвет обложки
                Color.black.opacity(0.1) // мягкая затемняющая подложка
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: artwork)
        )
    }

    
// MARK: - Загрузка
    private func loadMetadata() async {
        let tagFile = TLTagLibFile(fileURL: fileURL)
        if let parsed = tagFile.readMetadata() {
            var result: [(String, String)] = []

            result.append(("title", parsed.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            result.append(("artist", parsed.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            result.append(("album", parsed.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            result.append(("genre", parsed.genre?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            result.append(("comment", parsed.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))

            await MainActor.run { self.tags = result }

            if let data = parsed.artworkData, let img = UIImage(data: data) {
                await MainActor.run { self.artwork = img }
            }
        } else {
            await MainActor.run { self.tags = [] }
        }
    }

    
// MARK: - Метки для ключей
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
    
    
// MARK: - Человекочитаемый путь к файлу
    private func displayPath(from url: URL) -> String {
        let path = url.path

        if let range = path.range(of: "/File Provider Storage/") {
            let trimmed = path[range.upperBound...]
            return "iPhone: \(trimmed)"
        } else if let range = path.range(of: "/Mobile Documents/") {
            let trimmed = path[range.upperBound...]
            return "iCloud: \(trimmed)"
        } else {
            // fallback — родительская папка + имя файла
            let folder = url.deletingLastPathComponent().lastPathComponent
            return "\(folder)/\(url.lastPathComponent)"
        }
    }
}
