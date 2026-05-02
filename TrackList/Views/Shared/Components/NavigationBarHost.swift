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

    /// Показывать правую кнопку только на корневом экране NavigationStack
    let showsRightButtonOnlyOnRoot: Bool

    /// Контент sheet’а (чистый SwiftUI View)
    let content: Content

    // MARK: - Init

    init(
        title: String? = nil,
        rightButtonImage: String?,
        isRightEnabled: Binding<Bool>,
        onClose: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        showsRightButtonOnlyOnRoot: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.rightButtonImage = rightButtonImage
        self.isRightEnabled = isRightEnabled
        self.onClose = onClose
        self.onRightTap = onRightTap
        self.showsRightButtonOnlyOnRoot = showsRightButtonOnlyOnRoot
        self.content = content()
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UINavigationController {

        let hosting = UIHostingController(
            rootView: AnyView(
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        )
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
        guard let root = context.coordinator.hostingController else { return }
        guard let top = uiViewController.topViewController else { return }

        // Обновляем rootView только на корневом экране.
        // При активном NavigationLink перезапись rootView сбрасывает стек навигации.
        if top === root {
            root.rootView =
                AnyView(
                    content.frame(maxWidth: .infinity, maxHeight: .infinity)
                )
        }

        // если правой кнопки быть не должно
        guard let imageName = rightButtonImage else {
            root.navigationItem.rightBarButtonItem = nil
            if top !== root {
                top.navigationItem.rightBarButtonItem = nil
            }
            return
        }

        let isRoot = top === root

        if showsRightButtonOnlyOnRoot && !isRoot {
            top.navigationItem.rightBarButtonItem = nil
        }

        // если кнопки ещё нет — создаём
        if root.navigationItem.rightBarButtonItem == nil {

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

            root.navigationItem.rightBarButtonItem = item
        }

        // 1️⃣ enabled / disabled
        root.navigationItem.rightBarButtonItem?.isEnabled =
            isRightEnabled.wrappedValue

        // 2️⃣ обновляем IMAGE, если сменилась
        let currentImageName =
            root.navigationItem.rightBarButtonItem?
                .image?
                .accessibilityIdentifier

        if currentImageName != imageName {
            let image = UIImage(systemName: imageName)
            image?.accessibilityIdentifier = imageName
            root.navigationItem.rightBarButtonItem?.image = image
        }

        // 3️⃣ ОБЯЗАТЕЛЬНО обновляем STYLE
        root.navigationItem.rightBarButtonItem?.style =
            imageName == "checkmark" ? .prominent : .plain
    }

    func makeCoordinator() -> Coordinator {Coordinator()}

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var onClose: (() -> Void)?
        var onRightTap: (() -> Void)?
        var hostingController: UIHostingController<AnyView>?

        @objc func closeTapped() {onClose?()}
        @objc func rightTapped() {onRightTap?()}
    }
}
