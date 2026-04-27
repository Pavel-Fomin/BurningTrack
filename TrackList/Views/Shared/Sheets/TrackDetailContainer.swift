//
//  TrackDetailContainer.swift
//  TrackList
//
//  Контейнер экрана «О треке».
//  Отвечает за сценарий редактирования и сохранения метаданных.
//
//  Роль:
//  - владеет редактируемым состоянием
//  - хранит исходные значения
//  - вычисляет наличие изменений
//  - управляет кнопкой ✓
//  - выполняет сохранение и закрытие
//
//  Inline-редактирование:
//  - ввод выполняется в sheet
//  - сохранение — единым commit’ом
//
//  Created by Pavel Fomin on 22.01.2026.
//

import SwiftUI

struct TrackDetailContainer: View {
    
    let track: any TrackDisplayable
    let playerManager: PlayerManager
    
    
    @ObservedObject private var sheetManager = SheetManager.shared
    
    // MARK: - Mode
    
    @State private var mode: TrackDetailSheet.Mode = .view
    
    // MARK: - Editing state (текущее)
    
    @State private var editedFileName: String = ""
    @State private var editedValues: [EditableTrackField: String] = [:]
    @State private var artworkUIImage: UIImage?
    @State private var artworkEditState = ArtworkEditState(hadOriginalArtwork: false)
    
    // MARK: - Initial state (фиксируется при входе в edit)
    
    @State private var initialFileName: String = ""
    @State private var initialValues: [EditableTrackField: String] = [:]
    @State private var initialArtworkEditState = ArtworkEditState(hadOriginalArtwork: false)
    
    @State private var showStopPlayerAlert = false
    
    @State private var initialFileExtension: String = ""
    @State private var initialFullFileName: String = ""
    @State private var showFileNameConflictAlert = false
    
    // MARK: - Derived state
    
    /// Имя файла не может быть пустым
    private var isFileNameValid: Bool {
        !editedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Есть ли реальные изменения (с учётом trim)
    private var hasChanges: Bool {
        guard isFileNameValid else { return false }

        if trimmed(editedFileName) != trimmed(initialFileName) {
            return true
        }

        if trimmed(editedValues) != trimmed(initialValues) {
            return true
        }

        return artworkEditState != initialArtworkEditState
    }
    
    // MARK: - UI
    
    var body: some View {
        NavigationBarHost(
            title: "О треке",
            rightButtonImage: mode == .view ? "pencil" : "checkmark",
            isRightEnabled: .constant(
                mode == .view || hasChanges
            ),
            
            onClose: {
                switch mode {
                case .view:
                    sheetManager.closeActive()

                case .edit:
                    cancelEditing()
                }
            },
            
            onRightTap: {
                switch mode {
                case .view:
                    enterEditMode()

                case .edit:
                    saveAndClose()
                }
            }
        ) {
            TrackDetailSheet(
                track: track,
                mode: mode,
                editedValues: $editedValues,
                editedFileName: $editedFileName,
                artworkUIImage: $artworkUIImage,
                artworkEditState: $artworkEditState
            )
        }
        .alert(
            "Трек сейчас воспроизводится",
            isPresented: $showStopPlayerAlert
        ) {
            Button("Отмена", role: .cancel) {}
            
            Button("Остановить и сохранить") {
                playerManager.pause()
                playerManager.stopAccessingCurrentTrack()
                saveAndClose()
            }
        } message: {
            Text("Чтобы переименовать файл, нужно остановить воспроизведение.")
        }
        
        .alert(
            "Файл с таким именем уже существует",
            isPresented: $showFileNameConflictAlert
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Выберите другое имя файла.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .trackDidUpdate)) { notification in
            guard let updateEvent = notification.object as? TrackUpdateEvent else { return }
            guard updateEvent.trackId == track.id else { return }

            applySnapshotToSheetState(updateEvent.snapshot)
        }
    }
    
    // MARK: - Edit flow
    
    private func enterEditMode() {
        initialFileName = editedFileName
        initialValues = editedValues
        initialArtworkEditState = artworkEditState

        Task {
            if let entry = await TrackRegistry.shared.entry(for: track.id) {
                await MainActor.run {
                    initialFullFileName = entry.fileName
                }
            }
        }

        mode = .edit
    }
    
    // MARK: - Save
    
    private func saveAndClose() {

        let newFullName = buildFullFileName(editedName: editedFileName)
        let fileChanged = newFullName != initialFullFileName
        let tagsChanged = trimmed(editedValues) != trimmed(initialValues)
        let artworkAction = artworkEditState.makeWriteAction()
        let artworkChanged = artworkAction != .none
        
        guard hasChanges else {
            mode = .view
            return
        }

        Task {
            do {
                if fileChanged {
                    try await AppCommandExecutor.shared.renameTrack(
                        trackId: track.id,
                        to: newFullName,
                        using: playerManager
                    )
                }

                if tagsChanged || artworkChanged {
                    let patch = buildTagWritePatch()
                    try await AppCommandExecutor.shared.updateTrackTags(
                        trackId: track.id,
                        patch: patch,
                        artworkAction: artworkAction
                    )
                }

                await MainActor.run {
                    if let snapshot = TrackRuntimeStore.shared.snapshot(forTrackId: track.id) {
                        applySnapshotToSheetState(snapshot)
                    }

                    mode = .view
                }

            } catch let error as LibraryFileError {
                switch error {
                case .trackIsPlaying:
                    await MainActor.run { showStopPlayerAlert = true }

                case .destinationAlreadyExists:
                    await MainActor.run { showFileNameConflictAlert = true }

                default:
                    print("❌ File error:", error)
                }

            } catch {
                print("❌ Failed to save:", error)
            }
        }
    }
    
    // MARK: - Закрыть в режиме редактирования
    
    private func cancelEditing() {
        editedFileName = initialFileName
        editedValues = initialValues
        artworkEditState = initialArtworkEditState
        mode = .view
    }
    
    // MARK: - Tag patch
    
    private func buildTagWritePatch() -> TagWritePatch {
        var patch = TagWritePatch()

        // Локальная функция для строковых тегов.
        // Сравнивает исходное и текущее значение и возвращает:
        // - .unchanged, если поле не изменилось
        // - .clear, если пользователь очистил поле
        // - .set(...), если введено новое непустое значение
        func makeStringChange(
            field: EditableTrackField,
            initial: String
        ) -> TagFieldChange<String> {
            let current = (editedValues[field] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let initialTrimmed = initial.trimmingCharacters(in: .whitespacesAndNewlines)

            if current == initialTrimmed {return .unchanged}
            if current.isEmpty {return .clear}
            return .set(current)
        }

        // Локальная функция для числового тега year.
        // Семантика:
        // - .unchanged → значение не менялось
        // - .clear → поле очищено
        // - .set(Int) → введено корректное число
        //
        // Если введено невалидное непустое значение, пока считаем,
        // что patch не должен маскировать ошибку как clear.
        // На этом шаге возвращаем .unchanged, чтобы не сломать сборку.
        // Валидировать ввод будем следующим отдельным шагом.
        func makeYearChange(initial: String) -> TagFieldChange<Int> {
            let current = (editedValues[.year] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let initialTrimmed = initial.trimmingCharacters(in: .whitespacesAndNewlines)

            if current == initialTrimmed {return .unchanged}
            if current.isEmpty {return .clear}
            guard let value = Int(current) else {
                // Невалидный ввод — пока считаем как clear,
                // чтобы не возвращалось старое значение
                return .clear
            }
            return .set(value)
        }

        patch.title = makeStringChange(
            field: .title,
            initial: initialValues[.title] ?? ""
        )

        patch.artist = makeStringChange(
            field: .artist,
            initial: initialValues[.artist] ?? ""
        )

        patch.album = makeStringChange(
            field: .album,
            initial: initialValues[.album] ?? ""
        )

        patch.genre = makeStringChange(
            field: .genre,
            initial: initialValues[.genre] ?? ""
        )

        patch.comment = makeStringChange(
            field: .comment,
            initial: initialValues[.comment] ?? ""
        )

        patch.publisher = makeStringChange(
            field: .publisher,
            initial: initialValues[.publisher] ?? ""
        )

        patch.year = makeYearChange(
            initial: initialValues[.year] ?? ""
        )
        
        return patch
    }
    
    // MARK: - Helpers

    /// Применяет каноничный runtime snapshot к состоянию sheet.
    ///
    /// Используется после сохранения и при получении TrackUpdateEvent.
    /// Не читает файл напрямую и не обращается к TagLib.
    ///
    /// - Parameter snapshot: Актуальный runtime snapshot трека
    private func applySnapshotToSheetState(_ snapshot: TrackRuntimeSnapshot) {
        
        // Имя файла храним в поле редактирования без расширения.
        let fileNameWithoutExtension = makeFileNameWithoutExtension(snapshot.fileName)
        
        // Основные редактируемые поля sheet.
        let newValues: [EditableTrackField: String] = [
            .title: snapshot.title ?? "",
            .artist: snapshot.artist ?? "",
            .album: snapshot.album ?? "",
            .genre: snapshot.genre ?? "",
            .year: snapshot.year.map(String.init) ?? "",
            .publisher: snapshot.publisherOrLabel ?? "",
            .comment: snapshot.comment ?? ""
        ]
        
        // Обложку строим из artworkData внутри snapshot.
        let image = ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: snapshot.artworkData,
            purpose: .trackInfoSheet
        )
        
        editedFileName = fileNameWithoutExtension
        initialFileName = fileNameWithoutExtension
        initialFullFileName = snapshot.fileName
        initialFileExtension = (snapshot.fileName as NSString).pathExtension
        
        editedValues = newValues
        initialValues = newValues
        
        artworkUIImage = image
        artworkEditState = ArtworkEditState(hadOriginalArtwork: image != nil)
        initialArtworkEditState = artworkEditState
    }

    /// Возвращает имя файла без расширения.
    ///
    /// - Parameter fileName: Полное имя файла
    /// - Returns: Имя файла без расширения
    private func makeFileNameWithoutExtension(_ fileName: String) -> String {
        (fileName as NSString).deletingPathExtension
    }
    
    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func trimmed(_ dict: [EditableTrackField: String]) -> [EditableTrackField: String] {
        dict.mapValues { trimmed($0) }
    }
    
    private func buildFullFileName(editedName: String) -> String {

        let name =
            editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        let ext =
            (initialFullFileName as NSString).pathExtension

        guard !ext.isEmpty else {
            return name
        }

        return "\(name).\(ext)"
    }
}
