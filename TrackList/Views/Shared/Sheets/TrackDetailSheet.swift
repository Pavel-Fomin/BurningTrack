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
    @Binding var initialArtworkEditState: ArtworkEditState  /// Исходное состояние для отмены редактирования

    // MARK: - Runtime state

    @State private var resolvedURL: URL?                   /// URL файла для отображения пути
    @State private var fileTechnicalInfo = TrackDetailPresentationText.unavailableTechnicalValue /// Готовая строка технических данных
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
                    fileTechnicalInfo: fileTechnicalInfo,
                    fileName: editedFileName,
                    tags: [
                        (.title, editedValues[.title] ?? ""),
                        (.artist, editedValues[.artist] ?? ""),
                        (.album, editedValues[.album] ?? ""),
                        (.genre, editedValues[.genre] ?? ""),
                        (.year, editedValues[.year] ?? ""),
                        (.publisher, editedValues[.publisher] ?? ""),
                        (.comment, editedValues[.comment] ?? "")
                    ]
                )

            case .edit:
                TrackDetailEditForm(
                    fileName: $editedFileName,
                    values: $editedValues,
                    trackId: track.trackId,
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
        if let purchasedTrack = track.asPurchasedITunesPlayableTrack() {
            await loadPurchasedITunesRuntimeData(purchasedTrack)
            return
        }

        guard let url = await BookmarkResolver.url(forTrack: track.trackId) else {
            print("❌ BookmarkResolver: нет URL для трека \(track.trackId)")
            return
        }

        resolvedURL = url

        let snapshot = await loadSnapshot()
        guard let snapshot else { return }

        await applySnapshotToSheetState(snapshot)
    }

    /// Загружает runtime-данные iTunes-трека без BookmarkResolver и кэша метаданных.
    /// Sheet получает те же поля через TrackRuntimeSnapshot, что и обычные треки.
    /// - Parameter track: Runtime-модель купленного iTunes-трека
    private func loadPurchasedITunesRuntimeData(
        _ track: PurchasedITunesPlayableTrack
    ) async {
        let snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(
            forPurchasedITunesTrack: track
        )

        await MainActor.run {
            resolvedURL = nil
            TrackRuntimeStore.shared.storeSnapshot(snapshot)
        }
        await applySnapshotToSheetState(snapshot)
    }

    /// Загружает runtime snapshot трека из store или собирает через builder.
    /// - Returns: TrackRuntimeSnapshot или nil
    private func loadSnapshot() async -> TrackRuntimeSnapshot? {
        if let snapshot = TrackRuntimeStore.shared.snapshot(forTrackId: track.trackId) {
            return snapshot
        }

        return try? await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: track.trackId)
    }

    /// Применяет runtime snapshot к состоянию sheet.
    /// Не читает файл напрямую и не обращается к TagLib.
    /// - Parameter snapshot: Актуальный runtime snapshot трека
    @MainActor
    private func applySnapshotToSheetState(_ snapshot: TrackRuntimeSnapshot) async {

        let values: [EditableTrackField: String] = [
            .title: snapshot.title ?? "",
            .artist: snapshot.artist ?? "",
            .album: snapshot.album ?? "",
            .genre: snapshot.genre ?? "",
            .year: snapshot.year.map(String.init) ?? "",
            .publisher: snapshot.publisherOrLabel ?? "",
            .comment: snapshot.comment ?? ""
        ]

        editedFileName = makeFileNameWithoutExtension(snapshot.fileName)
        editedValues = values
        fileTechnicalInfo = TrackTechnicalMetadataFormatter.string(
            from: snapshot.technicalMetadata
        )
        let loadingArtworkState = ArtworkEditState(hadOriginalArtwork: false)
        artworkUIImage = nil
        artworkEditState = loadingArtworkState
        initialArtworkEditState = loadingArtworkState

        let image: UIImage?
        if let artworkRequest = ArtworkRequest(
            trackId: track.trackId,
            snapshot: snapshot,
            purpose: .trackInfoSheet
        ) {
            image = await ArtworkProvider.shared.image(for: artworkRequest)
        } else {
            image = nil
        }
        guard !Task.isCancelled else { return }
        let resolvedArtworkState = ArtworkEditState(hadOriginalArtwork: image != nil)
        artworkUIImage = image
        initialArtworkEditState = resolvedArtworkState
        // Не перезаписываем замену или удаление, сделанные до завершения подготовки оригинала.
        if artworkEditState == loadingArtworkState {
            artworkEditState = resolvedArtworkState
        }
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
            // После Mobile Documents первым компонентом находится системное имя iCloud Drive.
            let relativeComponents = path[range.upperBound...]
                .split(separator: "/", omittingEmptySubsequences: true)

            guard relativeComponents.first == "com~apple~CloudDocs" else {
                return "iCloud: /" + relativeComponents.joined(separator: "/")
            }

            let userPathComponents = relativeComponents.dropFirst()
            return "iCloud: /" + userPathComponents.joined(separator: "/")
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
