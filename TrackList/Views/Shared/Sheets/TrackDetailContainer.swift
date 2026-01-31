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

    @ObservedObject private var sheetManager = SheetManager.shared

    // MARK: - Mode

    @State private var mode: TrackDetailSheet.Mode = .view

    // MARK: - Editing state (текущее)

    @State private var editedFileName: String = ""
    @State private var editedValues: [EditableTrackField: String] = [:]

    // MARK: - Initial state (фиксируется при входе в edit)

    @State private var initialFileName: String = ""
    @State private var initialValues: [EditableTrackField: String] = [:]

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
    }

    // MARK: - Edit flow

    private func enterEditMode() {
        // фиксируем initial state
        initialFileName = editedFileName
        initialValues = editedValues

        mode = .edit
    }

    // MARK: - Save

    private func saveAndClose() {
        guard hasChanges else { return }

        let patch = buildTagWritePatch()

        Task {
            do {
                try await AppCommandExecutor.shared.updateTrackTags(
                    trackId: track.id,
                    patch: patch
                )

                await MainActor.run {
                    mode = .view
                    sheetManager.closeActive()
                }
            } catch {
                print("❌ Failed to update tags:", error)
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
}
