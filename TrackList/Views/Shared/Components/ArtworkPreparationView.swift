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

/// Безопасный placeholder предотвращает неявное создание рабочего provider вне Composition Root.
private actor UnavailableArtworkImageProvider: ArtworkImageProviding {
    func image(for request: ArtworkRequest) async -> UIImage? {
        nil
    }
}

/// Передаёт общую presentation-capability через окружение всем ветвям, использующим общий компонент.
private struct ArtworkImageProviderEnvironmentKey: EnvironmentKey {
    static let defaultValue: any ArtworkImageProviding = UnavailableArtworkImageProvider()
}

extension EnvironmentValues {
    /// Capability подготовки обложек создаётся только Composition Root.
    var artworkImageProvider: any ArtworkImageProviding {
        get { self[ArtworkImageProviderEnvironmentKey.self] }
        set { self[ArtworkImageProviderEnvironmentKey.self] = newValue }
    }
}

/// Выполняет один запрос к внедрённой artwork-capability вне SwiftUI body и без знания о production provider.
@MainActor
struct ArtworkImageLoader {
    /// Узкая capability приходит из Environment или из тестового boundary.
    private let provider: any ArtworkImageProviding

    init(provider: any ArtworkImageProviding) {
        self.provider = provider
    }

    /// Передаёт provider только непустой запрос, сохраняя placeholder для отсутствующей обложки.
    func image(for request: ArtworkRequest?) async -> UIImage? {
        guard let request else { return nil }

        return await provider.image(for: request)
    }
}

/// Показывает placeholder до получения изображения и не выполняет подготовку внутри body.
struct ArtworkPreparationView<ArtworkContent: View, Placeholder: View>: View {
    /// Запрос содержит только данные и лёгкую идентичность обложки.
    let request: ArtworkRequest?
    /// Готовое представление успешно подготовленной обложки.
    private let artworkContent: (UIImage) -> ArtworkContent
    /// Представление до завершения подготовки или после отрицательного результата.
    private let placeholder: () -> Placeholder
    /// Узкая capability приходит из Composition Root без обращения View к singleton.
    @Environment(\.artworkImageProvider) private var artworkImageProvider

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

            let preparedImage = await ArtworkImageLoader(
                provider: artworkImageProvider
            ).image(for: request)
            guard !Task.isCancelled else { return }
            image = preparedImage
        }
    }
}
