//
//  MiniPlayerView.swift
//  TrackList
//
//  Мини-плеер: отображает текущий трек, обложку, название, прогресс и кнопки управления
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var trackListViewModel: TrackListViewModel
    
    var body: some View {
        if let track = playerViewModel.currentTrack {
            VStack {
                
                // MARK: - Верхняя часть: обложка + информация + кнопки
                
                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        
                        // Обложка
                        if let artwork = track.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .cornerRadius(5)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .cornerRadius(5)
                        }
                        
                        // Информация о треке
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.artist ?? "Неизвестный артист")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(track.title ?? track.fileName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Кнопки управления
                        HStack(spacing: 8) {
                            Button(action: {
                                playerViewModel.playPreviousTrack()
                            }) {
                                Image(systemName: "backward.end.fill")
                                    .font(.body)
                            }
                            Button(action: {
                                playerViewModel.togglePlayPause()
                            }) {
                                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.body)
                            }
                            Button(action: {
                                playerViewModel.playNextTrack()
                            }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.body)
                            }
                        }
                    }
                    
                    // MARK: - Прогресс трека
                    
                    HStack(alignment: .center, spacing: 12) {
                        
                        // Текущее время
                        Text(formatTimeSmart(playerViewModel.currentTime))
                            .font(.caption2)
                            .frame(width: 40, alignment: .leading)
                        
                        // Ползунок прогресса
                        ProgressBar(
                            progress: {
                                let ratio = playerViewModel.trackDuration > 0
                                ? playerViewModel.currentTime / playerViewModel.trackDuration
                                : 0
                                return ratio
                            }(),
                            onSeek: { ratio in
                                let newTime = ratio * playerViewModel.trackDuration
                                playerViewModel.currentTime = newTime
                                playerViewModel.seek(to: newTime)
                            },
                            height: 10
                        )
                        
                        .id(playerViewModel.trackDuration)
                        
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4) // выравнивание по краям

                        // Оставшееся время
                        Text("-\(formatTimeSmart(playerViewModel.trackDuration - playerViewModel.currentTime))")
                            .font(.caption2)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.top, 8) // отступ между строками
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
    
}
