//
//  BatchTagArtworkReplacementPicker.swift
//  TrackList
//
//  Скрытый системный выбор изображения для замены обложки.
//
//  Created by Pavel Fomin on 09.06.2026.
//

import SwiftUI
import PhotosUI

/// Скрытый системный выбор изображения для замены обложки.
struct BatchTagArtworkReplacementPicker: ViewModifier {
    /// Цель, для которой выбирается новая обложка.
    @Binding var target: BatchTagArtworkActionTarget?
    /// Обработчик выбранного изображения.
    let onSelect: (BatchTagArtworkActionTarget, Data) -> Void
    /// Выбранный элемент системного picker.
    @State private var pickerItem: PhotosPickerItem?
    /// Показан ли системный выбор изображения.
    @State private var isPickerPresented = false
    /// Цель текущей операции выбора изображения.
    @State private var pendingTarget: BatchTagArtworkActionTarget?

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $pickerItem,
                matching: .images
            )
            .onChange(of: target) { _, newTarget in
                guard let newTarget else { return }
                pendingTarget = newTarget
                pickerItem = nil
                isPickerPresented = true
            }
            .onChange(of: isPickerPresented) { _, isPresented in
                guard !isPresented else { return }
                target = nil
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await handlePickerItem(newItem)
                }
            }
    }

    /// Обрабатывает выбранное изображение.
    private func handlePickerItem(_ item: PhotosPickerItem) async {
        guard let currentTarget = pendingTarget else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                resetPicker()
                return
            }
            await MainActor.run {
                onSelect(currentTarget, data)
                resetPicker()
            }
        } catch {
            resetPicker()
        }
    }

    /// Сбрасывает состояние выбора изображения.
    @MainActor
    private func resetPicker() {
        target = nil
        pendingTarget = nil
        pickerItem = nil
        isPickerPresented = false
    }
}

extension View {
    /// Подключает скрытый выбор изображения для замены обложки.
    func batchTagArtworkReplacementPicker(
        target: Binding<BatchTagArtworkActionTarget?>,
        onSelect: @escaping (BatchTagArtworkActionTarget, Data) -> Void
    ) -> some View {
        modifier(
            BatchTagArtworkReplacementPicker(
                target: target,
                onSelect: onSelect
            )
        )
    }
}
