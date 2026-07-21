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

    /// Вторичная строка заголовка.
    /// Если nil — используется стандартный системный title без кастомного titleView.
    let subtitle: String?

    /// System image name для правой кнопки (pencil / checkmark и т.д.)
    /// Если nil — кнопка не отображается
    let rightButtonImage: String?

    /// Управляет доступностью правой кнопки
    let isRightEnabled: Binding<Bool>

    /// Кнопка закрытия (×)
    let onClose: (() -> Void)?

    /// Accessibility-подпись кнопки закрытия.
    let closeAccessibilityLabel: String?

    /// Действие правой кнопки
    let onRightTap: (() -> Void)?

    /// Accessibility-подпись универсальной правой кнопки.
    let rightButtonAccessibilityLabel: String?

    /// Показывать правую кнопку только на корневом экране NavigationStack
    let showsRightButtonOnlyOnRoot: Bool

    /// Контент sheet’а (чистый SwiftUI View)
    let content: Content

    // MARK: - Init

    init(
        title: String? = nil,
        subtitle: String? = nil,
        rightButtonImage: String?,
        isRightEnabled: Binding<Bool>,
        onClose: (() -> Void)? = nil,
        closeAccessibilityLabel: String? = nil,
        onRightTap: (() -> Void)? = nil,
        rightButtonAccessibilityLabel: String? = nil,
        showsRightButtonOnlyOnRoot: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.rightButtonImage = rightButtonImage
        self.isRightEnabled = isRightEnabled
        self.onClose = onClose
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.onRightTap = onRightTap
        self.rightButtonAccessibilityLabel = rightButtonAccessibilityLabel
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
        configureTitle(for: hosting)

        // Кнопка закрытия (×)
        if onClose != nil {
            let item = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: context.coordinator,
                action: #selector(Coordinator.closeTapped)
            )
            item.accessibilityLabel = resolvedCloseAccessibilityLabel
            hosting.navigationItem.leftBarButtonItem = item
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

            item.accessibilityLabel = resolvedRightButtonAccessibilityLabel
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
        configureTitle(for: root)

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

            item.accessibilityLabel = resolvedRightButtonAccessibilityLabel
            root.navigationItem.rightBarButtonItem = item
        }

        // Обновляем доступность кнопки.
        root.navigationItem.rightBarButtonItem?.isEnabled =
            isRightEnabled.wrappedValue

        // Обновляем изображение, если оно изменилось.
        let currentImageName =
            root.navigationItem.rightBarButtonItem?
                .image?
                .accessibilityIdentifier

        if currentImageName != imageName {
            let image = UIImage(systemName: imageName)
            image?.accessibilityIdentifier = imageName
            root.navigationItem.rightBarButtonItem?.image = image
        }

        // Обязательно обновляем стиль.
        root.navigationItem.rightBarButtonItem?.style =
            imageName == "checkmark" ? .prominent : .plain
        root.navigationItem.rightBarButtonItem?.accessibilityLabel =
            resolvedRightButtonAccessibilityLabel
    }

    func makeCoordinator() -> Coordinator {Coordinator()}

    // MARK: - Accessibility

    private var resolvedCloseAccessibilityLabel: String {
        closeAccessibilityLabel ?? String(localized: "Close")
    }

    private var resolvedRightButtonAccessibilityLabel: String {
        rightButtonAccessibilityLabel ?? String(localized: "Done")
    }

    // MARK: - Title

    /// Настраивает заголовок navigation bar.
    private func configureTitle(for viewController: UIViewController) {
        guard let subtitle else {
            viewController.navigationItem.titleView = nil
            viewController.navigationItem.title = title
            return
        }

        viewController.navigationItem.title = nil
        viewController.navigationItem.titleView = makeTitleView(
            title: title,
            subtitle: subtitle
        )
    }

    /// Создаёт двухстрочный заголовок для sheet’ов, которым нужен subtitle.
    private func makeTitleView(
        title: String?,
        subtitle: String
    ) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2

        if let title, !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = .preferredFont(forTextStyle: .headline)
            titleLabel.textColor = .label
            titleLabel.numberOfLines = 1
            titleLabel.lineBreakMode = .byTruncatingTail
            stack.addArrangedSubview(titleLabel)
        }

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        stack.addArrangedSubview(subtitleLabel)

        return stack
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var onClose: (() -> Void)?
        var onRightTap: (() -> Void)?
        var hostingController: UIHostingController<AnyView>?

        @objc func closeTapped() {onClose?()}
        @objc func rightTapped() {onRightTap?()}
    }
}
