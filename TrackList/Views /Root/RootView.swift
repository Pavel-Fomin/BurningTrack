//
//  RootView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject var trackListViewModel: TrackListViewModel
    @StateObject var playerViewModel: PlayerViewModel
    @State private var isShowingOnboarding = false
    
    init() {
        let trackListVM = TrackListViewModel()
        _trackListViewModel = StateObject(wrappedValue: trackListVM)
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(trackListViewModel: trackListVM))
    }
    
    var body: some View {
        TrackListView(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
        .sheet(isPresented: $isShowingOnboarding) {
            OnboardingView(
                isPresented: $isShowingOnboarding,
                    steps: [
                        OnboardingStep(title: "Добро пожаловать в TrackList", description: "Это приложение для создания треклистов и записи на флешки."),
                        OnboardingStep(title: "Создайте свой первый треклист", description: "Нажмите на +, чтобы начать импорт треков."),
                        OnboardingStep(title: "Управляйте плейлистами", description: "Переименовывайте, удаляйте и перетаскивайте списки треков.")
                    ]
                )
            }
            .task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                isShowingOnboarding = true
            
            }
        }
    }

