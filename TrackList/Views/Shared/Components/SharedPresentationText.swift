//
//  SharedPresentationText.swift
//  TrackList
//
//  Локализованные подписи общих компонентов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Формирует параметризованные подписи, используемые несколькими общими компонентами.
enum SharedPresentationText {
    static var clearAccessibilityLabel: String {
        String(localized: "Clear")
    }

    static func operationProgress(
        processedCount: Int,
        totalCount: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "%1$lld of %2$lld"),
            processedCount,
            totalCount
        )
    }

    static func tracklistMembership(_ names: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Already in: %@"),
            names
        )
    }
}
