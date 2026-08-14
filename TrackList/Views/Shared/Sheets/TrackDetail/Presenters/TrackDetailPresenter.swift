//
//  TrackDetailPresenter.swift
//  TrackList
//
//  Преобразует runtime-данные и результаты команд в presentation Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Промежуточное presentation-представление одного загруженного трека.
struct TrackDetailLoadedPresentation {
    /// URL файла нужен только для повторного формирования presentation-пути после внешнего обновления.
    let fileURL: URL?
    /// Полное имя файла, необходимое только для корректного сохранения расширения.
    let fullFileName: String
    /// Имя файла без расширения для UI.
    let fileName: String
    /// Готовые значения редактируемых тегов.
    let editableValues: [EditableTrackField: String]
    /// Готовый путь к папке файла.
    let filePath: String?
    /// Готовая строка технической информации.
    let technicalInfo: String
    /// Запрос оригинальной artwork для общего UI подготовки preview.
    let originalArtworkRequest: ArtworkRequest?
    /// Признак существования raw artwork независимо от успешности её декодирования.
    let hasOriginalArtwork: Bool
}

/// Presentation-результат сохранения, который ViewModel применяет к экранному state.
enum TrackDetailSavePresentation {
    /// Сохранение подтверждено; snapshot может быть получен из результата или runtime store.
    case saved(snapshot: TrackRuntimeSnapshot?)
    /// Sheet остаётся в edit mode с необязательным системным alert.
    case keepEditing(alert: TrackDetailAlert?)
}

/// Формирует готовый presentation-state Track Detail и показывает стандартный feedback.
@MainActor
struct TrackDetailPresenter {
    /// Единый презентер пользовательских сообщений приложения.
    private let toastPresenter: any ToastPresenting

    init(toastPresenter: any ToastPresenting) {
        self.toastPresenter = toastPresenter
    }

    /// Преобразует runtime snapshot в presentation-данные без доступа к View.
    func makeLoadedPresentation(
        snapshot: TrackRuntimeSnapshot,
        fileURL: URL?
    ) -> TrackDetailLoadedPresentation {
        TrackDetailLoadedPresentation(
            fileURL: fileURL,
            fullFileName: snapshot.fileName,
            fileName: (snapshot.fileName as NSString).deletingPathExtension,
            editableValues: [
                .title: snapshot.title ?? "",
                .artist: snapshot.artist ?? "",
                .album: snapshot.album ?? "",
                .genre: snapshot.genre ?? "",
                .year: snapshot.year.map(String.init) ?? "",
                .publisher: snapshot.publisherOrLabel ?? "",
                .comment: snapshot.comment ?? ""
            ],
            filePath: fileURL.map {
                displayPath(from: $0.deletingLastPathComponent())
            },
            technicalInfo: TrackTechnicalMetadataFormatter.string(
                from: snapshot.technicalMetadata
            ),
            originalArtworkRequest: ArtworkRequest(
                trackId: snapshot.trackId,
                snapshot: snapshot,
                purpose: .trackInfoSheet
            ),
            hasOriginalArtwork: snapshot.artworkData != nil
        )
    }

    /// Собирает полное состояние экрана из готовых presentation-данных и текущего draft.
    func makeState(
        mode: TrackDetailMode,
        isLoading: Bool,
        isSaving: Bool,
        canEnterEdit: Bool,
        canSave: Bool,
        content: TrackDetailLoadedPresentation?,
        fileName: String,
        editableValues: [EditableTrackField: String],
        artwork: TrackDetailArtworkPresentationState,
        canUseFileNameStrategies: Bool,
        yearValidationMessage: String?,
        alert: TrackDetailAlert?
    ) -> TrackDetailScreenState {
        TrackDetailScreenState(
            mode: mode,
            isLoading: isLoading,
            isSaving: isSaving,
            canEnterEdit: canEnterEdit,
            canSave: canSave,
            fileName: fileName,
            editableValues: editableValues,
            filePath: content?.filePath,
            technicalInfo: content?.technicalInfo
                ?? TrackDetailPresentationText.unavailableTechnicalValue,
            artwork: artwork,
            canUseFileNameStrategies: canUseFileNameStrategies,
            yearValidationMessage: yearValidationMessage,
            alert: alert
        )
    }

    /// Формирует отображение artwork, сохраняя факт наличия raw artwork при ошибке preview.
    func makeArtworkPresentation(
        trackId: UUID,
        originalArtworkRequest: ArtworkRequest?,
        hasOriginalArtwork: Bool,
        artworkEditState: ArtworkEditState
    ) -> TrackDetailArtworkPresentationState {
        if let data = artworkEditState.newArtworkData,
           let revision = artworkEditState.newArtworkRevision {
            return TrackDetailArtworkPresentationState(
                request: ArtworkRequest(
                    trackId: trackId,
                    artworkData: data,
                    purpose: .trackInfoSheet,
                    sourceIdentifier: .transient(revision: revision)
                ),
                canAddArtwork: false,
                canRemoveArtwork: true
            )
        }

        if artworkEditState.isMarkedForRemoval {
            return TrackDetailArtworkPresentationState(
                request: nil,
                canAddArtwork: true,
                canRemoveArtwork: false
            )
        }

        return TrackDetailArtworkPresentationState(
            request: originalArtworkRequest,
            canAddArtwork: hasOriginalArtwork == false,
            canRemoveArtwork: hasOriginalArtwork
        )
    }

    /// Показывает стандартное сообщение успешного сохранения и возвращает новый snapshot.
    func present(
        _ result: TrackEditsSavedSuccess,
        confirmedSnapshot: TrackRuntimeSnapshot?
    ) -> TrackDetailSavePresentation {
        AppCommandToastPresenter(
            toastPresenter: toastPresenter
        ).present(result)
        return .saved(snapshot: confirmedSnapshot)
    }

    /// Преобразует ожидаемую AppError в alert или существующий Toast.
    func present(_ error: AppError) -> TrackDetailSavePresentation {
        switch error {
        case .fileAccessDenied:
            return .keepEditing(alert: .stopPlayback)

        case .fileAlreadyExists:
            return .keepEditing(alert: .fileNameConflict)

        default:
            AppCommandToastPresenter(
                toastPresenter: toastPresenter
            ).present(error)
            return .keepEditing(alert: nil)
        }
    }

    /// Показывает сообщение для неизвестной ошибки сохранения.
    func presentUnknownSaveFailure() -> TrackDetailSavePresentation {
        toastPresenter.handle(
            .operationFailed(
                message: TrackDetailPresentationText.saveFailedMessage
            )
        )
        return .keepEditing(alert: nil)
    }

    /// Возвращает локализованное пояснение невалидного year.
    func yearValidationMessage(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Int(trimmed) == nil else { return nil }
        return TrackDetailPresentationText.invalidYearMessage
    }

    /// Возвращает путь в согласованном с текущим UI формате.
    private func displayPath(from folderURL: URL) -> String {
        let path = folderURL.path

        if let range = path.range(of: "/File Provider Storage/") {
            return "iPhone: " + String(path[range.upperBound...])
        }

        if let range = path.range(of: "/Mobile Documents/") {
            let relativeComponents = path[range.upperBound...]
                .split(separator: "/", omittingEmptySubsequences: true)

            guard relativeComponents.first == "com~apple~CloudDocs" else {
                return "iCloud: /" + relativeComponents.joined(separator: "/")
            }

            return "iCloud: /" + relativeComponents
                .dropFirst()
                .joined(separator: "/")
        }

        // folderURL уже указывает на папку, поэтому компонент нельзя удалять повторно.
        return folderURL.lastPathComponent
    }
}
