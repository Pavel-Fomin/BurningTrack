//
//  ExportDestinationResolverTests.swift
//  TrackList
//
//  Проверки platform-границы системного выбора папки экспорта.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import UIKit
import XCTest
@testable import TrackList

/// Проверяет, что concrete resolver сам разрешает presenter на platform-границе.
@MainActor
final class ExportDestinationResolverTests: XCTestCase {

    /// Проверяет typed-ошибку без показа реального UIDocumentPicker.
    func testResolveDestinationWithoutPresenterThrowsTypedError() async {
        let resolver = ExportDestinationResolver(
            viewControllerProvider: UnavailableViewControllerProvider()
        )

        do {
            _ = try await resolver.resolveDestination()
            XCTFail("Ожидалась ошибка отсутствующего presenter")
        } catch let error as ExportDestinationResolverError {
            guard case .presenterUnavailable = error else {
                return XCTFail("Получена неверная ошибка: \(error)")
            }
        } catch {
            XCTFail("Получена нетипизированная ошибка: \(error)")
        }
    }
}

/// Не предоставляет контроллер, чтобы проверить ошибку platform-границы без picker-а.
@MainActor
private final class UnavailableViewControllerProvider: ViewControllerProviding {

    /// Подтверждает отсутствие доступного presenter для системной презентации.
    func topViewController() -> UIViewController? {
        nil
    }
}
