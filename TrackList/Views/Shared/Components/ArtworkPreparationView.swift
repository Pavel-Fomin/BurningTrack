//
//  ArtworkPreparationView.swift
//  TrackList
//
//  SwiftUI-подписка на результат асинхронной подготовки обложки.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import SwiftUI
import UIKit

/// Показывает placeholder до получения изображения и не выполняет подготовку внутри body.
struct ArtworkPreparationView<ArtworkContent: View, Placeholder: View>: View {
    /// Запрос содержит только данные и лёгкую идентичность обложки.
    let request: ArtworkRequest?
    /// Готовое представление успешно подготовленной обложки.
    private let artworkContent: (UIImage) -> ArtworkContent
    /// Представление до завершения подготовки или после отрицательного результата.
    private let placeholder: () -> Placeholder

    /// Результат общей подсистемы хранится локально только для обновления конкретного View.
    @State private var image: UIImage?

    /// Создаёт подписку с внешним оформлением изображения и placeholder.
    init(
        request: ArtworkRequest?,
        @ViewBuilder artworkContent: @escaping (UIImage) -> ArtworkContent,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.request = request
        self.artworkContent = artworkContent
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                artworkContent(image)
            } else {
                placeholder()
            }
        }
        .task(id: request?.loadIdentifier) {
            image = nil
            guard let request else { return }

            let preparedImage = await ArtworkProvider.shared.image(for: request)
            guard !Task.isCancelled else { return }
            image = preparedImage
        }
    }
}
