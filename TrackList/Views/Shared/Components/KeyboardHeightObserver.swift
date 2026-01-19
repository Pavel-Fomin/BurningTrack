//
//  KeyboardHeightObserver.swift
//  TrackList
//
//  Наблюдатель высоты системной клавиатуры.
//
//  Отслеживает появление, изменение высоты и скрытие клавиатуры
//  через уведомления UIKit и публикует актуальную высоту в рантайме.
//
//  Используется для корректного позиционирования UI-элементов
//  (например, inline edit bar) поверх контента,
//  без сдвига List и без вмешательства в системный layout.
//
//  Реализация:
//  - основана на UIKeyboard notifications
//  - учитывает multi-scene окружение (iOS 26+)
//  - не использует UIScreen.main
//  - не управляет фокусом и не закрывает клавиатуру
//
//  Класс является чистым утилитарным слоем UI-инфраструктуры
//  и не содержит бизнес-логики.
//
//  Created by PavelFomin on 19.01.2026.
//

import Foundation
import UIKit
import Combine

final class KeyboardHeightObserver: ObservableObject {

    @Published private(set) var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification
        )
        .compactMap { notification -> CGFloat? in
            guard
                let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return nil }

            guard
                let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first
            else {
                return 0
            }

            let screenHeight = windowScene.screen.bounds.height
            return max(0, screenHeight - frame.origin.y)
        }
        .receive(on: RunLoop.main)
        .assign(to: &$height)
    }
}
