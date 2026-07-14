//
//  MiniPlayerExpandedContent.swift
//  TrackList
//
//  Дополнительные действия расширенного мини-плеера.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI
import AVKit

struct MiniPlayerExpandedContent: View {

    // MARK: - Input

    let shuffleAction: (() -> Void)?
    let repeatAction: (() -> Void)?
    let repeatOneAction: (() -> Void)?
    let airPlayAction: (() -> Void)?
    let isShuffleEnabled: Bool
    let isRepeatAllEnabled: Bool
    let isRepeatOneEnabled: Bool

    // MARK: - UI

    var body: some View {
        HStack(spacing: 20) {
            optionalActionButton(
                systemName: "shuffle",
                accessibilityLabel: "Перемешать",
                action: shuffleAction,
                isActive: isShuffleEnabled
            )

            optionalActionButton(
                systemName: "repeat",
                accessibilityLabel: "Повтор",
                action: repeatAction,
                isActive: isRepeatAllEnabled
            )

            optionalActionButton(
                systemName: "repeat.1",
                accessibilityLabel: "Повтор одного трека",
                action: repeatOneAction,
                isActive: isRepeatOneEnabled
            )

            airPlayButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Optional actions

    /// Открывает системное меню выбора источника AirPlay.
    @ViewBuilder
    private var airPlayButton: some View {
        if let airPlayAction {
            optionalActionButton(
                systemName: "airplayaudio",
                accessibilityLabel: "AirPlay",
                action: airPlayAction
            )
        } else {
            MiniPlayerAirPlayRoutePicker()
                .frame(width: 40, height: 40)
                // Увеличиваем нативную иконку пропорционально переходу с 16 до 18 пунктов.
                .scaleEffect(1.125)
                .accessibilityLabel("AirPlay")
        }
    }

    /// Строит кнопку, которая становится неактивной до подключения действия.
    private func optionalActionButton(
        systemName: String,
        accessibilityLabel: String,
        action: (() -> Void)?,
        isActive: Bool? = nil
    ) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .foregroundStyle(isActive == true ? Color.accentColor : Color.primary)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Нативная кнопка AirPlay с системным меню доступных источников.
private struct MiniPlayerAirPlayRoutePicker: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .label
        view.tintColor = .secondaryLabel
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
