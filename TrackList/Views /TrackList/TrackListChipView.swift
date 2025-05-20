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
    
    
    var body: some View {
        Group {
            if isSelected {
                Menu {
                    Button("Добавить трек", action: onAdd)
                    
                    Button("Экспортировать") {
                        if let topVC = UIApplication.topViewController() {
                            ExportManager.shared.exportViaTempAndPicker(trackList.tracks, presenter: topVC)
                        } else {
                            print("❌ Не удалось получить topViewController")
                        }
                    }
                    
                } label: {
                    Text(formatTrackListLabel(from: trackList.createdAt))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue))
                        .foregroundColor(.white)
                }
                
            } else if isEditing && !isSelected {
                HStack(spacing: 4) {
                    Text(formatTrackListLabel(from: trackList.createdAt))
                        .foregroundColor(.primary)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gray.opacity(0.3)))
                .onTapGesture { onSelect() }
                .offset(x: isEditing && !isSelected
                        ? sin(wigglePhase + Double(trackList.id.uuidString.hashValue % 10)) * 2
                        : 0)
                .onAppear { startWiggle() }
                .onDisappear { stopWiggle() }
                
            } else {
                Text(formatTrackListLabel(from: trackList.createdAt))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.gray.opacity(0.3)))
                    .foregroundColor(.primary)
                    .onTapGesture { onSelect() }
            }
            
        }
        
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

