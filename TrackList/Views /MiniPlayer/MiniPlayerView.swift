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
import AVKit


struct AVRoutePickerViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .label
        view.tintColor = .secondaryLabel
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}


struct MiniPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    var trackListViewModel: TrackListViewModel?
    @State private var dragOffsetX: CGFloat = 0
    
    var body: some View {
        if let track = playerViewModel.currentTrackDisplayable {
            VStack {
                
                
                // MARK: - Верхняя часть: обложка + информация + кнопки
                
                HStack(spacing: 12) {
                    
                    // Анимируемая часть
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
                        
                        // Информация
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
                    }
                    .offset(x: dragOffsetX)
                    .animation(.spring(), value: dragOffsetX)
                    .contentShape(Rectangle()) // чтобы ловился tap по всей ширине
                    .onTapGesture {
                        playerViewModel.togglePlayPause()
                    }
                    
                    Spacer()
                    
                    // Airplay
                    AVRoutePickerViewWrapper()
                        .frame(width: 24, height: 24)
                    
                }
                .frame(height: 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffsetX = value.translation.width }
                        .onEnded { value in
                            let threshold: CGFloat = 30
                            if value.translation.width > threshold {
                                playerViewModel.playNextTrack()
                            } else if value.translation.width < -threshold {
                                playerViewModel.playPreviousTrack()
                            }
                            withAnimation(.spring()) { dragOffsetX = 0 }
                        }
                )
               
                
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
                    .padding(.horizontal, 4) /// выравнивание по краям
                    
                    // Оставшееся время
                    Text("-\(formatTimeSmart(playerViewModel.trackDuration - playerViewModel.currentTime))")
                        .font(.caption2)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.top, 8) /// отступ между строками
                
            }
            
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: MiniPlayerHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 0) /// отступ между плеером и меню
        }
    }
}
