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

// MARK: - Чип-вью для одного плейлиста
struct TrackListChipView: View {
    let trackList: TrackList
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var wigglePhase: Double = 0
    @State private var timer: Timer?
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var showDeleteAlert = false
    @State private var showClearAlert = false
    
    private var content: some View {
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

                    Button("Очистить треклист", role: .destructive) {
                        showClearAlert = true
                    }
                } label: {
                    Text(trackList.name)
                        .chipStyle(isSelected: true)
                }
                
                
                // 2) Активный чип в режиме редактирования
            } else if isSelected && isEditing {
                let tracks = TrackListManager.shared.loadTracks(for: trackList.id)
                
                HStack(spacing: 4) {
                    Text(trackList.name)
                    
                    if tracks.isEmpty {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .chipStyle(isSelected: true)
                .onTapGesture(perform: onSelect)
                
                // 3) Неактивный чип в режиме редактирования
            } else if isEditing {
                HStack(spacing: 4) {
                    Text(trackList.name)
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold))
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
    }
    
    
    // MARK: - Алерты
    
    var body: some View {
            content
            // Универсальный алерт удаления
                .alert("Удалить треклист?", isPresented: $showDeleteAlert) {
                    Button("Удалить", role: .destructive) { onDelete() }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("\"\(trackList.name)\"")
                }
            
            // Алерт переименования
                .alert("Переименовать треклист", isPresented: $isRenaming) {
                    TextField("Новое название треклиста", text: $newName)
                    Button("Сохранить") {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            TrackListManager.shared.renameTrackList(id: trackList.id, to: trimmed)
                            onEdit()
                        }
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("Новое название треклиста")
                }
        
                .alert("Очистить треклист?", isPresented: $showClearAlert) {
                    Button("Очистить", role: .destructive) {
                        NotificationCenter.default.post(name: .clearTrackList, object: trackList.id)
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("Все треки из \"\(trackList.name)\" будут удалены")
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
