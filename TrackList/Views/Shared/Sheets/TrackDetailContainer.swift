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
    
    // MARK: - Initial state (фиксируется при входе в edit)
    
    @State private var initialFileName: String = ""
    @State private var initialValues: [EditableTrackField: String] = [:]
    
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
        
        return trimmed(editedValues) != trimmed(initialValues)
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
                sheetManager.closeActive()
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
                editedFileName: $editedFileName
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
    }
    
    // MARK: - Edit flow
    
    private func enterEditMode() {
        initialFileName = editedFileName
        initialValues = editedValues

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

                if tagsChanged {
                    let patch = buildTagWritePatch()
                    try await AppCommandExecutor.shared.updateTrackTags(
                        trackId: track.id,
                        patch: patch
                    )
                }

                await MainActor.run {
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
    
    // MARK: - Tag patch
    
    private func buildTagWritePatch() -> TagWritePatch {
        var patch = TagWritePatch()
        
        for (field, value) in editedValues {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized: String? = trimmed.isEmpty ? nil : trimmed
            
            switch field {
            case .title:
                patch.title = normalized
            case .artist:
                patch.artist = normalized
            case .album:
                patch.album = normalized
            case .genre:
                patch.genre = normalized
            case .comment:
                patch.comment = normalized
            }
        }
        
        return patch
    }
    
    // MARK: - Helpers
    
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
