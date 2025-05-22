//
//  TrackListChipView.swift
//  TrackList
//
//  Чип-вью для одного плейлиста
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation
import SwiftUI

// MARK: - Основная view

struct TrackListChipView: View {
    let trackList: TrackList
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void
    let onDelete: () -> Void
    let isEditing: Bool
    let onEdit: () -> Void
    
    @State private var wigglePhase: Double = 0
    @State private var timer: Timer?
    @State private var isRenaming = false
    @State private var newName = ""
    
    
    var body: some View {
            Group {
                // 1) Активный чип вне режима редактирования — показываем Menu
                if isSelected && !isEditing {
                    Menu {
                        Button("Добавить трек", action: onAdd)
                        Button("Экспортировать") {
                            if let topVC = UIApplication.topViewController() {
                                let imported = TrackListManager.shared.loadTracks(for: trackList.id)
                                ExportManager.shared.exportViaTempAndPicker(imported, presenter: topVC)
                            }
                        }
                        Button("Переименовать") {
                            newName = trackList.name
                            isRenaming = true
                        }
                    } label: {
                        Text(trackList.name)
                            .chipStyle(isSelected: true)
                    }

                // 2) Активный чип в режиме редактирования — просто подсвеченный текст
                } else if isSelected && isEditing {
                    Text(trackList.name)
                        .chipStyle(isSelected: true)
                        .onTapGesture(perform: onSelect)

                // 3) Невыбранный чип в режиме редактирования — с кнопкой удаления и wiggle
                } else if isEditing {
                    HStack(spacing: 4) {
                        Text(trackList.name)
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .chipStyle(isSelected: false)
                    .offset(x: sin(wigglePhase + Double(trackList.id.uuidString.hashValue % 10)) * 2)
                    .onAppear { startWiggle() }
                    .onDisappear { stopWiggle() }
                    .onTapGesture(perform: onSelect)

                // 4) Обычный неактивный чип — только текст и tap
                } else {
                    Text(trackList.name)
                        .chipStyle(isSelected: false)
                        .onTapGesture(perform: onSelect)
                }
            }
            // Переименование
            .alert("Переименовать плейлист", isPresented: $isRenaming) {
                TextField("Новое название", text: $newName)
                Button("Сохранить") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        TrackListManager.shared.renameTrackList(id: trackList.id, to: trimmed)
                        onEdit()
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Введите новое название для плейлиста")
            }
        }

        // MARK: - Wiggle animation helpers
        private func startWiggle() {
            stopWiggle()
            timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                wigglePhase += 0.1
            }
        }
        private func stopWiggle() {
            timer?.invalidate()
            timer = nil
        }
    }

    // Утилита chipStyle уже объявлена отдельным модификатором
