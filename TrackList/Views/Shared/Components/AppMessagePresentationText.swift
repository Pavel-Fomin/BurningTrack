//
//  AppMessagePresentationText.swift
//  TrackList
//
//  Локализованные сообщения общих ошибок приложения.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Формирует короткие общие сообщения, не принадлежащие отдельному feature-flow.
enum AppMessagePresentationText {
    static var genericTrackTitle: String {
        String(localized: "toast.app.track")
    }

    static var unavailableValue: String {
        String(localized: "Unavailable")
    }

    static var fileNotFoundMessage: String {
        String(localized: "toast.app.fileNotFound")
    }

    static var fileAccessDeniedMessage: String {
        String(localized: "toast.app.fileAccessDenied")
    }

    static var bookmarkMissingMessage: String {
        String(localized: "toast.app.bookmarkMissing")
    }

    static var bookmarkStaleMessage: String {
        String(localized: "toast.app.bookmarkStale")
    }

    static var bookmarkResolveFailedMessage: String {
        String(localized: "toast.app.bookmarkResolveFailed")
    }

    static var bookmarkCreateFailedMessage: String {
        String(localized: "toast.app.bookmarkCreateFailed")
    }

    static var trackNotFoundMessage: String {
        String(localized: "toast.app.trackNotFound")
    }

    static var trackUnavailableMessage: String {
        String(localized: "toast.app.trackUnavailable")
    }

    static var presenterUnavailableMessage: String {
        String(localized: "toast.app.presenterUnavailable")
    }

    static var unknownErrorMessage: String {
        String(localized: "toast.app.unknownError")
    }
}
