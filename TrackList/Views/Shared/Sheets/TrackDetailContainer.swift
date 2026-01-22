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
    
    @State private var originalValues: [TrackDetailSheet.EditableField: String] = [:]
    @State private var editedValues: [TrackDetailSheet.EditableField: String] = [:]
    
    @State private var editingField: TrackDetailSheet.EditableField?
    
    // MARK: - Derived state
    
    private var hasChanges: Bool { editingField != nil && originalValues != editedValues }
    
    // MARK: - UI
    
    var body: some View {
        NavigationBarHost(
            title: "О треке",
            isRightEnabled: .constant(hasChanges),
            onClose: {
                sheetManager.closeActive()
            },
            onConfirm: {
                saveAndClose()
            }
        ) {
            TrackDetailSheet(
                track: track,
                editedValues: $editedValues,
                editingField: $editingField
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
