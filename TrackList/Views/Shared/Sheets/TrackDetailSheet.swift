//
//  TrackDetailSheet.swift
//  TrackList
//
//  Экран "О треке" — глобальный sheet.
//
//  Роль:
//  - управляет режимами просмотра и редактирования
//  - получает данные трека через TrackRuntimeSnapshot
//  - собирает экран из read-only и edit форм
//
//  Created by Pavel Fomin on 13.10.2025.
//

import SwiftUI

struct TrackDetailSheet: View {

    // MARK: - Input

    let track: any TrackDisplayable  /// Трек, для которого открыт sheet
    let mode: Mode                   /// Текущий режим sheet

    enum Mode: Equatable {
        case view                    /// Режим просмотра
        case edit                    /// Режим редактирования
    }

    // MARK: - Editing state (из контейнера)

    @Binding var editedValues: [EditableTrackField: String] /// Значения редактируемых тегов
    @Binding var editedFileName: String                     /// Редактируемое имя файла без расширения
    @Binding var artworkUIImage: UIImage?                   /// Обложка для отображения в sheet
    @Binding var artworkEditState: ArtworkEditState         /// Состояние редактирования обложки

    // MARK: - Runtime state

    @State private var resolvedURL: URL?                   /// URL файла для отображения пути
    @State private var didLoad = false                     /// Флаг первичной загрузки sheet

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
                    artworkUIImage: artworkUIImage,
                    artworkEditState: $artworkEditState
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

    /// Загружает первичные данные sheet.
    /// URL используется только для отображения пути.
    /// Метаданные и artwork берутся из TrackRuntimeSnapshot.
    private func load() async {
        guard let url = await BookmarkResolver.url(forTrack: track.id) else {
            print("❌ BookmarkResolver: нет URL для трека \(track.id)")
            return
        }

        resolvedURL = url

        let snapshot = await loadSnapshot()
        guard let snapshot else { return }

        await MainActor.run {
            applySnapshotToSheetState(snapshot)
        }
    }

    /// Загружает runtime snapshot трека из store или собирает через builder.
    /// - Returns: TrackRuntimeSnapshot или nil
    private func loadSnapshot() async -> TrackRuntimeSnapshot? {
        if let snapshot = TrackRuntimeStore.shared.snapshot(forTrackId: track.id) {
            return snapshot
        }

        return await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: track.id)
    }

    /// Применяет runtime snapshot к состоянию sheet.
    /// Не читает файл напрямую и не обращается к TagLib.
    /// - Parameter snapshot: Актуальный runtime snapshot трека
    private func applySnapshotToSheetState(_ snapshot: TrackRuntimeSnapshot) {

        let values: [EditableTrackField: String] = [
            .title: snapshot.title ?? "",
            .artist: snapshot.artist ?? "",
            .album: snapshot.album ?? "",
            .genre: snapshot.genre ?? "",
            .year: snapshot.year.map(String.init) ?? "",
            .publisher: snapshot.publisherOrLabel ?? "",
            .comment: snapshot.comment ?? ""
        ]

        let image = ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: snapshot.artworkData,
            purpose: .trackInfoSheet
        )

        editedFileName = makeFileNameWithoutExtension(snapshot.fileName)
        editedValues = values
        artworkUIImage = image
        artworkEditState = ArtworkEditState(hadOriginalArtwork: image != nil)
    }
    
    // MARK: - Helpers

    /// Возвращает путь для отображения в sheet.
    /// - Parameter url: URL папки файла
    /// - Returns: Человекочитаемый путь
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

    /// Возвращает имя файла без расширения.
    /// - Parameter fileName: Полное имя файла
    /// - Returns: Имя файла без расширения
    private func makeFileNameWithoutExtension(_ fileName: String) -> String {
        (fileName as NSString).deletingPathExtension
    }
}
