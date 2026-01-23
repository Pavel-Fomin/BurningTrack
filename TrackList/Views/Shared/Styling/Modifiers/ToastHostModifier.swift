//
//  ToastHostModifier.swift
//  TrackList
//
//  Унифицированный контейнер отображения ToastView.
//  Подключается один раз на уровне корня UI.
//  Не содержит бизнес-логики.
//
//  Created by Pavel Fomin on 2026.
//

import SwiftUI

struct ToastHostModifier: ViewModifier {

    @ObservedObject private var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if let data = toastManager.data {
                VStack {
                    ToastView(data: data)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.55), value: toastManager.data)
                        .padding(.top, topInset + 12)

                    Spacer()
                }
                .zIndex(1000)
            }
        }
    }

    /// Safe-area inset сверху (Dynamic Island / Notch / статусбар)
    private var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.top ?? 44
    }
}

extension View {
    /// Подключает отображение тостов поверх текущего UI
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}
