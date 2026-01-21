//
//  NavigationBarHost.swift
//  TrackList
//
//  UIKit-хост для sheet’ов с системным navigation bar.
//
//  Роль:
//  - предоставляет НАСТОЯЩИЙ UIKit navigation bar внутри SwiftUI sheet
//  - создаёт системные UIBarButtonItem (× / ✓)
//  - управляет состоянием enabled / disabled кнопки подтверждения
//
//  ВАЖНО:
//  - использует ТОЛЬКО контрактный API UIKit
//  - НЕ содержит бизнес-логики
//  - НЕ знает, что именно делает кнопка (save / rename / apply)
//  - НЕ владеет состоянием формы
//
//  Является инфраструктурным слоем UI.
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import UIKit

struct NavigationBarHost<Content: View>: UIViewControllerRepresentable {

    // MARK: - Configuration

    let title: String?                  /// Заголовок navigation bar. Может быть nil, если заголовок не требуется.
    let isRightEnabled: Binding<Bool>   /// Управляет доступностью кнопки подтверждения. Значение приходит из контейнера
    let onClose: (() -> Void)?          /// Действие для кнопки закрытия. Если nil — кнопка не отображается.
    let onConfirm: (() -> Void)?        /// Действие для кнопки подтверждения. Если nil — кнопка не отображается.
    let content: Content                /// Контент sheet’а (чистый SwiftUI View).

    // MARK: - Init

    init(
        title: String? = nil,
        isRightEnabled: Binding<Bool>,
        onClose: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isRightEnabled = isRightEnabled
        self.onClose = onClose
        self.onConfirm = onConfirm
        self.content = content()
    }

    // MARK: - UIViewControllerRepresentable
    
    // Создаёт UIKit-иерархию для отображения SwiftUI-контента внутри UINavigationController.
    // Здесь настраивается navigation bar:
    func makeUIViewController(context: Context) -> UINavigationController {

        /// SwiftUI-контент, встроенный в UIKit
        let hosting = UIHostingController(rootView: content)
        hosting.navigationItem.title = title

        /// Закрытие sheet’а
        if onClose != nil {
            hosting.navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: context.coordinator,
                action: #selector(Coordinator.closeTapped)
            )
        }

        /// Подтверждение действия
        if onConfirm != nil {
            hosting.navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "checkmark"),
                style: .prominent, // системный стиль iOS 26+
                target: context.coordinator,
                action: #selector(Coordinator.confirmTapped)
            )
        }

        /// Прозрачный фон, чтобы не появлялась лишняя подложка sheet’а
        hosting.view.backgroundColor = .clear

        let nav = UINavigationController(rootViewController: hosting)
        nav.view.backgroundColor = .clear

        /// Пробрасываем действия в Coordinator
        context.coordinator.onClose = onClose
        context.coordinator.onConfirm = onConfirm

        return nav
    }

    // Обновляет уже созданный UIKit-контроллер при изменении входных данных SwiftUI.
    // Используется для синхронизации enabled-состояния кнопки подтверждения (✓)
    // на основе Binding isRightEnabled.
    func updateUIViewController(
        _ uiViewController: UINavigationController,
        context: Context
    ) {
        // Синхронизация enabled-состояния кнопки подтверждения (✓)
        uiViewController
            .topViewController?
            .navigationItem
            .rightBarButtonItem?
            .isEnabled = isRightEnabled.wrappedValue
    }

    // Создаёт Coordinator для связи UIKit target/action с SwiftUI-замыканиями.
    // Coordinator живёт на стороне UIKit и вызывается через селекторы кнопок.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    // Coordinator используется для связи UIKit target/action с замыканиями из SwiftUI.
    final class Coordinator: NSObject {
        
        var onClose: (() -> Void)?     /// Обработчик нажатия на кнопку закрытия (×)
        var onConfirm: (() -> Void)?   /// Обработчик нажатия на кнопку подтверждения (✓)

        @objc func closeTapped() { onClose?() }     /// Вызывается при нажатии на кнопку закрытия. .Только уведомляет контейнер.
        @objc func confirmTapped() { onConfirm?() } /// Вызывается при нажатии на кнопку подтверждения.  только уведомляет контейнер.
    }
}
