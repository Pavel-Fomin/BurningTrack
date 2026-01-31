//
//  NavigationBarHost.swift
//  TrackList
//
//  UIKit-хост для sheet’ов с системным navigation bar.
//
//  Роль:
//  - предоставляет НАСТОЯЩИЙ UIKit navigation bar внутри SwiftUI sheet
//  - создаёт системные UIBarButtonItem (× / универсальная правая кнопка)
//  - управляет состоянием enabled / disabled правой кнопки
//
//  ВАЖНО:
//  - использует ТОЛЬКО контрактный API UIKit
//  - НЕ содержит бизнес-логики
//  - НЕ знает, что означает кнопка (edit / save / apply)
//  - НЕ владеет состоянием формы
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import UIKit

struct NavigationBarHost<Content: View>: UIViewControllerRepresentable {

    // MARK: - Configuration

    let title: String?

    /// System image name для правой кнопки (pencil / checkmark и т.д.)
    /// Если nil — кнопка не отображается
    let rightButtonImage: String?

    /// Управляет доступностью правой кнопки
    let isRightEnabled: Binding<Bool>

    /// Кнопка закрытия (×)
    let onClose: (() -> Void)?

    /// Действие правой кнопки
    let onRightTap: (() -> Void)?

    /// Контент sheet’а (чистый SwiftUI View)
    let content: Content

    // MARK: - Init

    init(
        title: String? = nil,
        rightButtonImage: String?,
        isRightEnabled: Binding<Bool>,
        onClose: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.rightButtonImage = rightButtonImage
        self.isRightEnabled = isRightEnabled
        self.onClose = onClose
        self.onRightTap = onRightTap
        self.content = content()
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UINavigationController {

        let hosting = UIHostingController(rootView: content)
        context.coordinator.hostingController = hosting
        hosting.navigationItem.title = title

        // Кнопка закрытия (×)
        if onClose != nil {
            hosting.navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: context.coordinator,
                action: #selector(Coordinator.closeTapped)
            )
        }

        // Универсальная правая кнопка
        if let imageName = rightButtonImage {

            let style: UIBarButtonItem.Style =
                imageName == "checkmark" ? .prominent : .plain

            let item = UIBarButtonItem(
                image: UIImage(systemName: imageName),
                style: style,
                target: context.coordinator,
                action: #selector(Coordinator.rightTapped)
            )

            hosting.navigationItem.rightBarButtonItem = item
            item.isEnabled = isRightEnabled.wrappedValue
        }

        hosting.view.backgroundColor = .clear

        let nav = UINavigationController(rootViewController: hosting)
        nav.view.backgroundColor = .clear

        context.coordinator.onClose = onClose
        context.coordinator.onRightTap = onRightTap

        return nav
    }

    func updateUIViewController(
        _ uiViewController: UINavigationController,
        context: Context
    ) {
        // обновляем SwiftUI-контент
        context.coordinator.hostingController?.rootView = content

        guard let top = uiViewController.topViewController else { return }

        // если правой кнопки быть не должно
        guard let imageName = rightButtonImage else {
            top.navigationItem.rightBarButtonItem = nil
            return
        }

        // если кнопки ещё нет — создаём
        if top.navigationItem.rightBarButtonItem == nil {

            let style: UIBarButtonItem.Style =
                imageName == "checkmark" ? .prominent : .plain

            let image = UIImage(systemName: imageName)
            image?.accessibilityIdentifier = imageName

            let item = UIBarButtonItem(
                image: image,
                style: style,
                target: context.coordinator,
                action: #selector(Coordinator.rightTapped)
            )

            top.navigationItem.rightBarButtonItem = item
        }

        // 1️⃣ enabled / disabled
        top.navigationItem.rightBarButtonItem?.isEnabled =
            isRightEnabled.wrappedValue

        // 2️⃣ обновляем IMAGE, если сменилась
        let currentImageName =
            top.navigationItem.rightBarButtonItem?
                .image?
                .accessibilityIdentifier

        if currentImageName != imageName {
            let image = UIImage(systemName: imageName)
            image?.accessibilityIdentifier = imageName
            top.navigationItem.rightBarButtonItem?.image = image
        }

        // 3️⃣ ОБЯЗАТЕЛЬНО обновляем STYLE
        top.navigationItem.rightBarButtonItem?.style =
            imageName == "checkmark" ? .prominent : .plain
    }

    func makeCoordinator() -> Coordinator {Coordinator()}

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var onClose: (() -> Void)?
        var onRightTap: (() -> Void)?
        var hostingController: UIHostingController<Content>?

        @objc func closeTapped() {onClose?()}
        @objc func rightTapped() {onRightTap?()}
    }
}
