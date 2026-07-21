//
//  FileRenameProposalBuilder.swift
//  TrackList
//
//  Генератор предложений для будущего переименования файлов треков.
//  Формирует новое имя файла из тегов или ручного ввода без физической работы с файловой системой.
//
//  Created by Pavel Fomin on 16.05.2026.
//

import Foundation

/// Генератор доменных предложений по переименованию файлов треков.
struct FileRenameProposalBuilder {

    /// Создает предложение по переименованию на основе выбранной стратегии.
    func makeProposal(
        from input: FileRenameInput,
        strategy: FileRenameStrategy,
        manualName: String? = nil
    ) -> FileRenameProposal {
        switch strategy {
        case .artistTitle:
            return makeTagBasedProposal(from: input, strategy: .artistTitle)

        case .titleArtist:
            return makeTagBasedProposal(from: input, strategy: .titleArtist)

        case .manual:
            return makeManualProposal(from: input, manualName: manualName)
        }
    }

    /// Создает предложение из тегов исполнителя и названия трека.
    private func makeTagBasedProposal(
        from input: FileRenameInput,
        strategy: FileRenameStrategy
    ) -> FileRenameProposal {
        let artist = normalized(input.artist)
        let title = normalized(input.title)

        guard !artist.isEmpty, !title.isEmpty else {
            return FileRenameProposal(
                trackId: input.trackId,
                oldFileName: input.currentFileName,
                newFileName: input.currentFileName,
                strategy: strategy,
                status: .skipped(reason: .tagsMissing)
            )
        }

        let baseName: String

        switch strategy {
        case .artistTitle:
            baseName = "\(artist) - \(title)"

        case .titleArtist:
            baseName = "\(title) - \(artist)"

        case .manual:
            baseName = ""
        }

        return makeReadyProposal(
            from: input,
            baseName: baseName,
            strategy: strategy
        )
    }

    /// Создает предложение из имени файла, заданного пользователем вручную.
    private func makeManualProposal(
        from input: FileRenameInput,
        manualName: String?
    ) -> FileRenameProposal {
        let baseName = normalized(manualName)

        guard !baseName.isEmpty else {
            return FileRenameProposal(
                trackId: input.trackId,
                oldFileName: input.currentFileName,
                newFileName: input.currentFileName,
                strategy: .manual,
                status: .skipped(reason: .emptyFileName)
            )
        }

        return makeReadyProposal(
            from: input,
            baseName: baseName,
            strategy: .manual
        )
    }

    /// Собирает готовое предложение и сохраняет расширение исходного файла.
    private func makeReadyProposal(
        from input: FileRenameInput,
        baseName: String,
        strategy: FileRenameStrategy
    ) -> FileRenameProposal {
        let sanitizedBaseName = sanitizedFileName(baseName)
        let newFileName = fileNameWithOriginalExtension(
            baseName: sanitizedBaseName,
            originalFileName: input.currentFileName
        )

        guard !sanitizedBaseName.isEmpty else {
            return FileRenameProposal(
                trackId: input.trackId,
                oldFileName: input.currentFileName,
                newFileName: input.currentFileName,
                strategy: strategy,
                status: .skipped(reason: .invalidFileName)
            )
        }

        guard newFileName != input.currentFileName else {
            return FileRenameProposal(
                trackId: input.trackId,
                oldFileName: input.currentFileName,
                newFileName: newFileName,
                strategy: strategy,
                status: .skipped(reason: .unchangedFileName)
            )
        }

        return FileRenameProposal(
            trackId: input.trackId,
            oldFileName: input.currentFileName,
            newFileName: newFileName,
            strategy: strategy,
            status: .ready
        )
    }

    /// Добавляет к новому имени расширение исходного файла, если оно было.
    private func fileNameWithOriginalExtension(
        baseName: String,
        originalFileName: String
    ) -> String {
        let originalURL = URL(fileURLWithPath: originalFileName)
        let originalExtension = originalURL.pathExtension

        guard !originalExtension.isEmpty else {
            return baseName
        }

        return "\(baseName).\(originalExtension)"
    }

    /// Убирает пробелы и переносы строк по краям значения.
    private func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Заменяет запрещенные в имени файла символы пробелами.
    private func sanitizedFileName(_ value: String) -> String {
        let forbiddenCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = value.components(separatedBy: forbiddenCharacters)
        return parts
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
