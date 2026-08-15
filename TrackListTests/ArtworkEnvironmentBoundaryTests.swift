//
//  ArtworkEnvironmentBoundaryTests.swift
//  TrackList
//
//  Проверяет безопасный default и injection artwork-capability на presentation boundary.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import SwiftUI
import UIKit
import XCTest
@testable import TrackList

/// Проверяет, что общий artwork-компонент получает provider только через Environment boundary.
@MainActor
final class ArtworkEnvironmentBoundaryTests: XCTestCase {
    /// Default Environment не подменяется production ArtworkProvider и безопасно возвращает placeholder-result.
    func testEnvironmentDefaultUsesNonProductionProvider() async {
        let provider = EnvironmentValues().artworkImageProvider
        let request = makeRequest()
        let image = await provider.image(for: request)

        XCTAssertFalse(provider is ArtworkProvider)
        XCTAssertNil(image)
    }

    /// Внедрённый provider получает исходный запрос через минимальный loader общего SwiftUI-компонента.
    func testInjectedProviderReceivesArtworkRequest() async {
        let expectedImage = UIImage()
        let provider = ArtworkEnvironmentProviderSpy(result: expectedImage)
        let request = makeRequest()
        let loader = ArtworkImageLoader(provider: provider)

        let image = await loader.image(for: request)

        XCTAssertTrue(image === expectedImage)
        XCTAssertEqual(provider.requests, [request])
    }

    /// Отсутствующий request сохраняет placeholder-семантику и не вызывает injected provider.
    func testNilRequestDoesNotCallInjectedProvider() async {
        let provider = ArtworkEnvironmentProviderSpy(result: UIImage())
        let loader = ArtworkImageLoader(provider: provider)

        let image = await loader.image(for: nil)

        XCTAssertNil(image)
        XCTAssertTrue(provider.requests.isEmpty)
    }

    /// Создаёт минимальный request, достаточный для проверки границы без ImageIO и кэша.
    private func makeRequest() -> ArtworkRequest {
        let data = Data([1, 2, 3])

        return ArtworkRequest(
            trackId: UUID(),
            artworkData: data,
            purpose: .trackList,
            sourceIdentifier: .embeddedArtwork(data: data)
        )
    }
}

/// Фиксирует обращения loader к injected capability без реального ArtworkProvider.
@MainActor
private final class ArtworkEnvironmentProviderSpy: ArtworkImageProviding {
    private let result: UIImage?
    private(set) var requests: [ArtworkRequest] = []

    init(result: UIImage?) {
        self.result = result
    }

    /// Сохраняет фактический request и возвращает заранее подготовленный результат.
    func image(for request: ArtworkRequest) async -> UIImage? {
        requests.append(request)
        return result
    }
}
