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
            if isSelected {
                Menu {
                    Button("Добавить трек", action: onAdd)
                    Button("Экспортировать") {
                        if let topVC = UIApplication.topViewController() {
                            let importedTracks = TrackListManager.shared.loadTracks(for: trackList.id)
                            ExportManager.shared.exportViaTempAndPicker(importedTracks, presenter: topVC)
                        } else {
                            print("❌ Не удалось получить topViewController")
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
                
            } else if isEditing {
                HStack(spacing: 4) {
                    Text(trackList.name)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .chipStyle(isSelected: false)
                .onTapGesture { onSelect() }
                .offset(x: sin(wigglePhase + Double(trackList.id.uuidString.hashValue % 10)) * 2)
                .onAppear { startWiggle() }
                .onDisappear { stopWiggle() }
                
            } else {
                Text(trackList.name)
                    .chipStyle(isSelected: false)
                    .onTapGesture { onSelect() }
            }
        }
        
        .alert("Переименовать плейлист", isPresented: $isRenaming, actions: {
            TextField("Новое название", text: $newName)
                .onChange(of: newName) { newValue in
                    if newValue.count > 72 {
                        newName = String(newValue.prefix(72))
                    }
                }
            
            Button("Сохранить", role: .none) {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    TrackListManager.shared.renameTrackList(id: trackList.id, to: trimmed)
                    onEdit() /// обновляем данные
                }
            }
            
            Button("Отмена", role: .cancel) {}
        }, message: {
            Text("Введите новое название для плейлиста")
        })
    }
        
        // MARK: - Wiggle animation
        
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

