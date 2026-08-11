//
//  SearchContainer.swift
//  TrackList
//
//  Соединяет экран Search с единым feature-графом.
//  Created by Pavel Fomin on 11.08.2026.
//

import SwiftUI

struct SearchContainer: View {
    /// MainTabView и MainSidebarView используют состояние только для нижней геометрии.
    @Binding private var isSearchActive: Bool
    /// Store сохраняет единый граф Search при пересчётах SwiftUI View.
    @StateObject private var screenStore: SearchScreenStore

    init(
        featureFactory: SearchFeatureFactory,
        isSearchActive: Binding<Bool>
    ) {
        _isSearchActive = isSearchActive
        _screenStore = StateObject(
            wrappedValue: featureFactory.makeScreenStore()
        )
    }

    var body: some View {
        SearchScreen(
            viewModel: screenStore.viewModel,
            actionHandler: screenStore.actionHandler,
            isSearchActive: $isSearchActive
        )
    }
}
