//
//  LibraryFileSizeResolver.swift
//  TrackList
//
//  Получение надёжно доступного размера локального аудиофайла.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Получает размер файла только из атрибутов файловой системы, не открывая его содержимое.
enum LibraryFileSizeResolver {
    /// Возвращает размер доступного файла либо nil, если размер сейчас нельзя надёжно определить.
    static func fileSize(for fileURL: URL) -> Int64? {
        let resourceValues = try? fileURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ]
        )

        return resolvedFileSize(
            fileSize: resourceValues?.fileSize,
            isUbiquitousItem: resourceValues?.isUbiquitousItem,
            downloadingStatus: resourceValues?.ubiquitousItemDownloadingStatus
        )
    }

    /// Не подменяет неизвестный размер нулём и не использует размер недогруженного iCloud-файла.
    static func resolvedFileSize(
        fileSize: Int?,
        isUbiquitousItem: Bool?,
        downloadingStatus: URLUbiquitousItemDownloadingStatus?
    ) -> Int64? {
        let isAvailableLocally = downloadingStatus == .current || downloadingStatus == .downloaded

        guard isUbiquitousItem != true || isAvailableLocally,
              let fileSize,
              fileSize >= 0 else {
            return nil
        }

        return Int64(fileSize)
    }
}
