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
    
    // MARK: - Editing state
    
    @State private var mode: TrackDetailSheet.Mode = .view
    @State private var editedFileName: String = ""
    @State private var isEditingFileName: Bool = false
    @State private var editedValues: [EditableTrackField: String] = [:]
    
    // MARK: - Derived state
    
    private var hasChanges: Bool {!editedValues.isEmpty}
    
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
                if mode == .view {
                    mode = .edit
                } else {
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
    
    
    // MARK: - Save
    
    private func saveAndClose() {
        guard hasChanges else {
            sheetManager.closeActive()
            return
        }
        
        let patch = buildTagWritePatch()
        
        Task {
            do {
                try await AppCommandExecutor.shared.updateTrackTags(
                    trackId: track.id,
                    patch: patch
                )
                
                await MainActor.run {
                    sheetManager.closeActive()
                }
            } catch {
                // Ошибку пока не глотаем молча — позже сюда ляжет UX
                print("❌ Failed to update tags:", error)
            }
        }
    }
    
    
    // MARK: - Формирует доменный TagWritePatch на основе текущих inline-изменений
    
    /// Используется при нажатии кнопки ✓ в navigation bar.Пустое значение трактуется как удаление тега
    private func buildTagWritePatch() -> TagWritePatch {
        var patch = TagWritePatch()

        for (field, value) in editedValues {
            // пустая строка = удаление тега
            let normalized: String? = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : value

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
}
